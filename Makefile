SHELL := /bin/bash
TF ?= terraform
ENV_FILE ?= .env

.PHONY: init plan apply apply-auto fmt validate destroy

init:
	@echo ">> terraform init"
	@$(TF) init

plan:
	@echo ">> terraform plan"
	@set -e; \
	if [ -f "$(ENV_FILE)" ]; then \
	  echo "Cargando variables desde $(ENV_FILE)"; \
	  set -a; . "$(ENV_FILE)"; set +a; \
	fi; \
	if [ -z "$$SES_EMAIL_IDENTITY" ]; then \
	  echo "SES_EMAIL_IDENTITY no está definido. Puedes definirlo en $(ENV_FILE) o así:"; \
	  echo '  SES_EMAIL_IDENTITY="mi-correo@dominio.com" make plan'; \
	  exit 1; \
	fi; \
	$(TF) plan -var "ses_email_identity=$$SES_EMAIL_IDENTITY"

apply:
	@echo ">> terraform apply (con confirmación)"
	@set -e; \
	if [ -f "$(ENV_FILE)" ]; then \
	  echo "Cargando variables desde $(ENV_FILE)"; \
	  set -a; . "$(ENV_FILE)"; set +a; \
	fi; \
	if [ -z "$$SES_EMAIL_IDENTITY" ]; then \
	  echo "SES_EMAIL_IDENTITY no está definido. Puedes definirlo en $(ENV_FILE) o así:"; \
	  echo '  SES_EMAIL_IDENTITY="mi-correo@dominio.com" make apply'; \
	  exit 1; \
	fi; \
	$(TF) apply -var "ses_email_identity=$$SES_EMAIL_IDENTITY"

apply-auto:
	@echo ">> terraform apply -auto-approve"
	@set -e; \
	if [ -f "$(ENV_FILE)" ]; then \
	  echo "Cargando variables desde $(ENV_FILE)"; \
	  set -a; . "$(ENV_FILE)"; set +a; \
	fi; \
	if [ -z "$$SES_EMAIL_IDENTITY" ]; then \
	  echo "SES_EMAIL_IDENTITY no está definido. Puedes definirlo en $(ENV_FILE) o así:"; \
	  echo '  SES_EMAIL_IDENTITY="mi-correo@dominio.com" make apply-auto'; \
	  exit 1; \
	fi; \
	$(TF) apply -auto-approve -var "ses_email_identity=$$SES_EMAIL_IDENTITY"

fmt:
	@echo ">> terraform fmt"
	@$(TF) fmt

validate:
	@echo ">> terraform validate"
	@$(TF) validate

destroy:
	@echo ">> terraform destroy"
	@set -e; \
	if [ -f "$(ENV_FILE)" ]; then \
	  echo "Cargando variables desde $(ENV_FILE)"; \
	  set -a; . "$(ENV_FILE)"; set +a; \
	fi; \
	if [ -z "$$SES_EMAIL_IDENTITY" ]; then \
	  echo "SES_EMAIL_IDENTITY no está definido. Puedes definirlo en $(ENV_FILE) o así:"; \
	  echo '  SES_EMAIL_IDENTITY="mi-correo@dominio.com" make destroy'; \
	  exit 1; \
	fi; \
	$(TF) destroy -var "ses_email_identity=$$SES_EMAIL_IDENTITY"

