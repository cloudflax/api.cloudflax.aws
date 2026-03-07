SHELL := /bin/bash
TF ?= terraform
ENV_FILE ?= .env

.PHONY: init plan apply apply-auto fmt validate destroy

# Carga .env y valida las variables requeridas.
# Exporta TF_VAR_* para las variables de Terraform.
define load_env
	@set -e; \
	if [ -f "$(ENV_FILE)" ]; then \
	  set -a; . "$(ENV_FILE)"; set +a; \
	fi; \
	if [ -z "$$ENVIRONMENT" ]; then \
	  echo "ERROR: ENVIRONMENT no está definido en $(ENV_FILE)"; exit 1; \
	fi; \
	if [ -z "$$AWS_REGION" ]; then \
	  echo "ERROR: AWS_REGION no está definido en $(ENV_FILE)"; exit 1; \
	fi; \
	if [ -z "$$AWS_PROFILE" ] && [ -z "$$AWS_ACCESS_KEY_ID" ]; then \
	  echo "ERROR: Define AWS_PROFILE o (AWS_ACCESS_KEY_ID y AWS_SECRET_ACCESS_KEY) en $(ENV_FILE)"; exit 1; \
	fi; \
	if [ -z "$$SES_EMAIL_IDENTITY" ]; then \
	  echo "ERROR: SES_EMAIL_IDENTITY no está definido en $(ENV_FILE)"; exit 1; \
	fi; \
	if [ -z "$$DB_PASSWORD" ]; then \
	  echo "ERROR: DB_PASSWORD no está definido en $(ENV_FILE)"; exit 1; \
	fi; \
	if [ -z "$$DB_SECRET_ARN" ]; then \
	  echo "ERROR: DB_SECRET_ARN no está definido en $(ENV_FILE)"; exit 1; \
	fi; \
	export TF_VAR_environment="$$ENVIRONMENT"; \
	export TF_VAR_aws_region="$$AWS_REGION"; \
	export TF_VAR_aws_profile="$$([ -n "$$AWS_ACCESS_KEY_ID" ] && echo '' || echo "$$AWS_PROFILE")"; \
	export TF_VAR_ses_email_identity="$$SES_EMAIL_IDENTITY"; \
	export TF_VAR_db_password="$$DB_PASSWORD"; \
	export TF_VAR_db_secret_arn="$$DB_SECRET_ARN"
endef

init:
	@echo ">> terraform init"
	@$(TF) init

plan:
	@echo ">> terraform plan"
	@set -e; \
	if [ -f "$(ENV_FILE)" ]; then set -a; . "$(ENV_FILE)"; set +a; fi; \
	[ -z "$$ENVIRONMENT" ]        && echo "ERROR: ENVIRONMENT no definido"        && exit 1 || true; \
	[ -z "$$AWS_REGION" ]         && echo "ERROR: AWS_REGION no definido"         && exit 1 || true; \
	( [ -n "$$AWS_PROFILE" ] || ( [ -n "$$AWS_ACCESS_KEY_ID" ] && [ -n "$$AWS_SECRET_ACCESS_KEY" ] ) ) || ( echo "ERROR: Define AWS_PROFILE o AWS_ACCESS_KEY_ID y AWS_SECRET_ACCESS_KEY en .env"; exit 1 ); \
	[ -z "$$SES_EMAIL_IDENTITY" ] && echo "ERROR: SES_EMAIL_IDENTITY no definido" && exit 1 || true; \
	[ -z "$$DB_PASSWORD" ]        && echo "ERROR: DB_PASSWORD no definido"        && exit 1 || true; \
	[ -z "$$DB_SECRET_ARN" ]      && echo "ERROR: DB_SECRET_ARN no definido"      && exit 1 || true; \
	export TF_VAR_environment="$$ENVIRONMENT"; \
	export TF_VAR_aws_region="$$AWS_REGION"; \
	export TF_VAR_aws_profile="$$([ -n "$$AWS_ACCESS_KEY_ID" ] && echo '' || echo "$$AWS_PROFILE")"; \
	export TF_VAR_ses_email_identity="$$SES_EMAIL_IDENTITY"; \
	export TF_VAR_db_password="$$DB_PASSWORD"; \
	export TF_VAR_db_secret_arn="$$DB_SECRET_ARN"; \
	$(TF) plan

apply:
	@echo ">> terraform apply (con confirmación)"
	@set -e; \
	if [ -f "$(ENV_FILE)" ]; then set -a; . "$(ENV_FILE)"; set +a; fi; \
	[ -z "$$ENVIRONMENT" ]        && echo "ERROR: ENVIRONMENT no definido"        && exit 1 || true; \
	[ -z "$$AWS_REGION" ]         && echo "ERROR: AWS_REGION no definido"         && exit 1 || true; \
	( [ -n "$$AWS_PROFILE" ] || ( [ -n "$$AWS_ACCESS_KEY_ID" ] && [ -n "$$AWS_SECRET_ACCESS_KEY" ] ) ) || ( echo "ERROR: Define AWS_PROFILE o AWS_ACCESS_KEY_ID y AWS_SECRET_ACCESS_KEY en .env"; exit 1 ); \
	[ -z "$$SES_EMAIL_IDENTITY" ] && echo "ERROR: SES_EMAIL_IDENTITY no definido" && exit 1 || true; \
	[ -z "$$DB_PASSWORD" ]        && echo "ERROR: DB_PASSWORD no definido"        && exit 1 || true; \
	[ -z "$$DB_SECRET_ARN" ]      && echo "ERROR: DB_SECRET_ARN no definido"      && exit 1 || true; \
	export TF_VAR_environment="$$ENVIRONMENT"; \
	export TF_VAR_aws_region="$$AWS_REGION"; \
	export TF_VAR_aws_profile="$$([ -n "$$AWS_ACCESS_KEY_ID" ] && echo '' || echo "$$AWS_PROFILE")"; \
	export TF_VAR_ses_email_identity="$$SES_EMAIL_IDENTITY"; \
	export TF_VAR_db_password="$$DB_PASSWORD"; \
	export TF_VAR_db_secret_arn="$$DB_SECRET_ARN"; \
	$(TF) apply

apply-auto:
	@echo ">> terraform apply -auto-approve"
	@set -e; \
	if [ -f "$(ENV_FILE)" ]; then set -a; . "$(ENV_FILE)"; set +a; fi; \
	[ -z "$$ENVIRONMENT" ]        && echo "ERROR: ENVIRONMENT no definido"        && exit 1 || true; \
	[ -z "$$AWS_REGION" ]         && echo "ERROR: AWS_REGION no definido"         && exit 1 || true; \
	( [ -n "$$AWS_PROFILE" ] || ( [ -n "$$AWS_ACCESS_KEY_ID" ] && [ -n "$$AWS_SECRET_ACCESS_KEY" ] ) ) || ( echo "ERROR: Define AWS_PROFILE o AWS_ACCESS_KEY_ID y AWS_SECRET_ACCESS_KEY en .env"; exit 1 ); \
	[ -z "$$SES_EMAIL_IDENTITY" ] && echo "ERROR: SES_EMAIL_IDENTITY no definido" && exit 1 || true; \
	[ -z "$$DB_PASSWORD" ]        && echo "ERROR: DB_PASSWORD no definido"        && exit 1 || true; \
	[ -z "$$DB_SECRET_ARN" ]      && echo "ERROR: DB_SECRET_ARN no definido"      && exit 1 || true; \
	export TF_VAR_environment="$$ENVIRONMENT"; \
	export TF_VAR_aws_region="$$AWS_REGION"; \
	export TF_VAR_aws_profile="$$([ -n "$$AWS_ACCESS_KEY_ID" ] && echo '' || echo "$$AWS_PROFILE")"; \
	export TF_VAR_ses_email_identity="$$SES_EMAIL_IDENTITY"; \
	export TF_VAR_db_password="$$DB_PASSWORD"; \
	export TF_VAR_db_secret_arn="$$DB_SECRET_ARN"; \
	$(TF) apply -auto-approve

fmt:
	@echo ">> terraform fmt"
	@$(TF) fmt

validate:
	@echo ">> terraform validate"
	@$(TF) validate

destroy:
	@echo ">> terraform destroy"
	@set -e; \
	if [ -f "$(ENV_FILE)" ]; then set -a; . "$(ENV_FILE)"; set +a; fi; \
	[ -z "$$ENVIRONMENT" ]        && echo "ERROR: ENVIRONMENT no definido"        && exit 1 || true; \
	[ -z "$$AWS_REGION" ]         && echo "ERROR: AWS_REGION no definido"         && exit 1 || true; \
	( [ -n "$$AWS_PROFILE" ] || ( [ -n "$$AWS_ACCESS_KEY_ID" ] && [ -n "$$AWS_SECRET_ACCESS_KEY" ] ) ) || ( echo "ERROR: Define AWS_PROFILE o AWS_ACCESS_KEY_ID y AWS_SECRET_ACCESS_KEY en .env"; exit 1 ); \
	[ -z "$$SES_EMAIL_IDENTITY" ] && echo "ERROR: SES_EMAIL_IDENTITY no definido" && exit 1 || true; \
	[ -z "$$DB_PASSWORD" ]        && echo "ERROR: DB_PASSWORD no definido"        && exit 1 || true; \
	[ -z "$$DB_SECRET_ARN" ]      && echo "ERROR: DB_SECRET_ARN no definido"      && exit 1 || true; \
	export TF_VAR_environment="$$ENVIRONMENT"; \
	export TF_VAR_aws_region="$$AWS_REGION"; \
	export TF_VAR_aws_profile="$$([ -n "$$AWS_ACCESS_KEY_ID" ] && echo '' || echo "$$AWS_PROFILE")"; \
	export TF_VAR_ses_email_identity="$$SES_EMAIL_IDENTITY"; \
	export TF_VAR_db_password="$$DB_PASSWORD"; \
	export TF_VAR_db_secret_arn="$$DB_SECRET_ARN"; \
	$(TF) destroy
