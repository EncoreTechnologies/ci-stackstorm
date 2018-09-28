################################################################################
# Description:
#  Executes testing and validation for python code and configuration files
#  within a StackStorm pack.
#
# =============================================

#PACK_DIR := $(dir $(realpath $(firstword $(MAKEFILE_LIST))))
ROOT_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
PACK_DIR := $(ROOT_DIR)/../
CI_DIR ?= $(ROOT_DIR)
YAML_FILES := $(shell git ls-files '*.yaml' '*.yml')
JSON_FILES := $(shell git ls-files '*.json')
PY_FILES   := $(shell git ls-files '*.py')
ROOT_VIRTUALENV ?= ""
VIRTUALENV_DIR ?= $(ROOT_DIR)/virtualenv
ST2_VIRTUALENV_DIR ?= "/tmp/st2-pack-tests-virtualenvs"
ST2_REPO_PATH ?= $(CI_DIR)/st2
ST2_REPO_BRANCH ?= master
LINT_CONFIGS_DIR ?= $(CI_DIR)/lint-configs/

PACK_NAME ?= Caller_needs_to_set_variable_PACK_NAME

export ST2_REPO_PATH ROOT_DIR

# All components are prefixed by st2
COMPONENTS := $(wildcard /tmp/st2/st2*)

.PHONY: all
# don't register right now (requires us to install stackstorm)
#all: requirements lint packs-resource-register packs-tests
all: requirements lint packs-tests

.PHONY: pack-name
pack-name:
	@echo $(PACK_NAME)

.PHONY: clean
clean: .clean-st2-repo .clean-virtualenv .clean-pack

.PHONY: lint
lint: requirements flake8 pylint configs-check metadata-check

.PHONY: flake8
flake8: requirements .flake8

.PHONY: pylint
pylint: requirements .clone-st2-repo .pylint

.PHONY: configs-check
configs-check: requirements .clone-st2-repo .copy-pack-to-subdirectory .configs-check

.PHONY: metadata-check
metadata-check: requirements .metadata-check

# list all makefile targets
.PHONY: list
list:
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$' | xargs

# Task which copies pack to temporary sub-directory so we can use old-style check scripts which
# # require pack to be in a sub-directory
.PHONY: .copy-pack-to-subdirectory
.copy-pack-to-subdirectory:
	mkdir -p /tmp/packs/$(PACK_NAME)
	cd $(PACK_DIR);	find . -name 'ci' -prune -or -name '.git' -or -type f -exec cp --parents '{}' '/tmp/packs/$(PACK_NAME)' ';'

.PHONY: .clean-pack
.clean-pack:
	@echo
	@echo "==================== cleaning packs ===================="
	@echo
	@echo "Start Time = `date --iso-8601=ns`"
	rm -rf /tmp/packs
	@echo "End Time = `date --iso-8601=ns`"

.PHONY: packs-resource-register
packs-resource-register: requirements .clone-st2-repo .copy-pack-to-subdirectory .install-mongodb .packs-resource-register

.PHONY: packs-missing-tests
packs-missing-tests: requirements .packs-missing-tests

.PHONY: packs-tests
packs-tests: requirements .clone-st2-repo .packs-tests

.PHONY: test
test: packs-tests

.PHONY: .flake8
.flake8:
	@echo
	@echo "==================== flake8 ===================="
	@echo
	@echo "Start Time = `date --iso-8601=ns`"
	. $(VIRTUALENV_DIR)/bin/activate; \
	for py in $(PY_FILES); do \
		flake8 --config $(LINT_CONFIGS_DIR)/python/.flake8 $$py || exit 1; \
	done
	@echo "End Time = `date --iso-8601=ns`"


.PHONY: .pylint
.pylint:
	@echo
	@echo "==================== pylint ===================="
	@echo
	@echo "Start Time = `date --iso-8601=ns`"
	. $(VIRTUALENV_DIR)/bin/activate; \
	REQUIREMENTS_DIR=$(CI_DIR)/ CONFIG_DIR=$(LINT_CONFIGS_DIR) ST2_REPO_PATH=${ST2_REPO_PATH} st2-check-pylint-pack $(PACK_DIR) || exit 1;
	@echo "End Time = `date --iso-8601=ns`"


.PHONY: .configs-check
.configs-check:
	@echo
	@echo "==================== configs-check ===================="
	@echo
	@echo "Start Time = `date --iso-8601=ns`"
	. $(VIRTUALENV_DIR)/bin/activate; \
	for yaml in $(YAML_FILES); do \
		st2-check-validate-yaml-file $$yaml || exit 1; \
	done
	. $(VIRTUALENV_DIR)/bin/activate; \
	for json in $(JSON_FILES); do \
		st2-check-validate-json-file $$json || exit 1; \
	done
	@echo "End Time = `date --iso-8601=ns`"
	@echo
	@echo "==================== example config check ===================="
	@echo
	@echo "Start Time = `date --iso-8601=ns`"
	. $(VIRTUALENV_DIR)/bin/activate; \
	ST2_REPO_PATH=${ST2_REPO_PATH} st2-check-validate-pack-example-config /tmp/packs/$(PACK_NAME) || exit 1;
	@echo "End Time = `date --iso-8601=ns`"

.PHONY: .metadata-check
.metadata-check:
	@echo
	@echo "==================== metadata-check ===================="
	@echo
	@echo "Start Time = `date --iso-8601=ns`"
	. $(VIRTUALENV_DIR)/bin/activate; \
	ST2_REPO_PATH=${ST2_REPO_PATH} st2-check-validate-pack-metadata-exists $(PACK_DIR) || exit 1;
	@echo "End Time = `date --iso-8601=ns`"

.PHONY: .install-mongodb
.install-monogodb:
# @todo
# install_mongodb() {
#   ST2_MONGODB_PASSWORD=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 24 ; echo '')
#   # Add key and repo for the latest stable MongoDB (3.2)
#   sudo rpm --import https://www.mongodb.org/static/pgp/server-3.2.asc
#   sudo sh -c "cat <<EOT > /etc/yum.repos.d/mongodb-org-3.2.repo
# [mongodb-org-3.2]
# name=MongoDB Repository
# baseurl=https://repo.mongodb.org/yum/redhat/7/mongodb-org/3.2/x86_64/
# gpgcheck=1
# enabled=1
# gpgkey=https://www.mongodb.org/static/pgp/server-3.2.asc
# EOT"
#   sudo yum -y install mongodb-org
#   # Configure MongoDB to listen on localhost only
#   sudo sed -i -e "s#bindIp:.*#bindIp: 127.0.0.1#g" /etc/mongod.conf
#   sudo systemctl start mongod
#   sudo systemctl enable mongod
#   sleep 5
#   # Create admin user and user used by StackStorm (MongoDB needs to be running)
#   mongo <<EOF
# use admin;
# db.createUser({
#     user: "admin",
#     pwd: "${ST2_MONGODB_PASSWORD}",
#     roles: [
#         { role: "userAdminAnyDatabase", db: "admin" }
#     ]
# });
# quit();
# EOF
#   mongo <<EOF
# use st2;
# db.createUser({
#     user: "stackstorm",
#     pwd: "${ST2_MONGODB_PASSWORD}",
#     roles: [
#         { role: "readWrite", db: "st2" }
#     ]
# });
# quit();
# EOF
#   # Require authentication to be able to acccess the database
#   sudo sh -c 'echo -e "security:\n  authorization: enabled" >> /etc/mongod.conf'
#   # MongoDB needs to be restarted after enabling auth
#   sudo systemctl restart mongod
# }


.PHONY: .packs-resource-register
.packs-resource-register:
	@echo
	@echo "==================== packs-resource-register ===================="
	@echo
	@echo "Start Time = `date --iso-8601=ns`"
	. $(VIRTUALENV_DIR)/bin/activate; \
	ST2_CONFIG_FILE=$(CI_DIR)/st2.tests.conf ST2_REPO_PATH=${ST2_REPO_PATH} st2-check-register-pack-resources /tmp/packs/$(PACK_NAME) || exit 1;
	@echo "End Time = `date --iso-8601=ns`"


.PHONY: .packs-tests
.packs-tests:
	@echo
	@echo "==================== packs-tests ===================="
	@echo
	@echo "Start Time = `date --iso-8601=ns`"
	. $(VIRTUALENV_DIR)/bin/activate; \
	ST2_REPO_PATH=${ST2_REPO_PATH} $(ST2_REPO_PATH)/st2common/bin/st2-run-pack-tests -x -p $(PACK_DIR) || exit 1;
	@echo "End Time = `date --iso-8601=ns`"

.PHONY: .packs-missing-tests
.packs-missing-tests:
	@echo
	@echo "==================== pack-missing-tests ===================="
	@echo
	@echo "Start Time = `date --iso-8601=ns`"
	. $(VIRTUALENV_DIR)/bin/activate; \
	st2-check-print-pack-tests-coverage $(PACK_DIR) || exit 1;
	@echo "End Time = `date --iso-8601=ns`"

.PHONY: .clone-st2-repo
.clone-st2-repo:
	@echo
	@echo "==================== cloning st2 repo ===================="
	@echo
	@echo "Start Time = `date --iso-8601=ns`"
	if [ ! -d "$(ST2_REPO_PATH)" ]; then \
		git clone https://github.com/StackStorm/st2.git --depth 1 --single-branch --branch $(ST2_REPO_BRANCH) $(ST2_REPO_PATH); \
	else \
		cd $(ST2_REPO_PATH); \
		git pull; \
	fi;
	@echo "End Time = `date --iso-8601=ns`"

.PHONY: .clean-st2-repo
.clean-st2-repo:
	@echo
	@echo "==================== cleaning st2 repo ===================="
	@echo
	@echo "Start Time = `date --iso-8601=ns`"
	rm -rf $(ST2_REPO_PATH)
	@echo "End Time = `date --iso-8601=ns`"

.PHONY: requirements
requirements: virtualenv
	@echo
	@echo "==================== requirements ===================="
	@echo
	@echo "Start Time = `date --iso-8601=ns`"
	. $(VIRTUALENV_DIR)/bin/activate; \
	$(VIRTUALENV_DIR)/bin/pip install --cache-dir $(HOME)/.pip-cache --upgrade pip; \
	$(VIRTUALENV_DIR)/bin/pip install --cache-dir $(HOME)/.pip-cache -q -r $(CI_DIR)/requirements-dev.txt; \
	$(VIRTUALENV_DIR)/bin/pip install --cache-dir $(HOME)/.pip-cache -q -r $(CI_DIR)/requirements-pack-tests.txt;
	@echo "End Time = `date --iso-8601=ns`"

.PHONY: virtualenv
virtualenv: $(VIRTUALENV_DIR)/bin/activate
$(VIRTUALENV_DIR)/bin/activate:
	@echo
	@echo "==================== virtualenv ===================="
	@echo
	@echo "Start Time = `date --iso-8601=ns`"
	if [ ! -d "$(VIRTUALENV_DIR)" ]; then \
		if [ -d "$(ROOT_VIRTUALENV)" ]; then \
			$(ROOT_DIR)/bin/clonevirtualenv.py $(ROOT_VIRTUALENV) $(VIRTUALENV_DIR);\
		else \
			virtualenv --no-site-packages $(VIRTUALENV_DIR);\
		fi; \
	fi;
	@echo "End Time = `date --iso-8601=ns`"


.PHONY: .clean-virtualenv
.clean-virtualenv:
	@echo
	@echo "==================== cleaning virtualenv ===================="
	@echo
	@echo "Start Time = `date --iso-8601=ns`"
	rm -rf $(VIRTUALENV_DIR)
	@echo "End Time = `date --iso-8601=ns`"
