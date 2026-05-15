.PHONY: help envvar \
				check_links check_spelling \
				build build_img \
				status run stop run_versioned verify_versioned

# COLORS
RED    := $(shell tput -Txterm setaf 1)
GREEN  := $(shell tput -Txterm setaf 2)
YELLOW := $(shell tput -Txterm setaf 3)
VIOLET := $(shell tput -Txterm setaf 5)
AQUA   := $(shell tput -Txterm setaf 6)
WHITE  := $(shell tput -Txterm setaf 7)
RESET  := $(shell tput -Txterm sgr0)


TARGET_MAX_CHAR_NUM=20

PYTHON ?= python3
PIP ?= pip3

LOCAL_SERVER_PORT ?= 8000


## Show help
help:
	@echo ''
	@echo 'Makefile for user-guide mkdocs application'
	@echo ''
	@echo 'Usage:'
	@echo '  ${YELLOW}make${RESET} ${GREEN}<target>${RESET}'
	@echo ''
	@echo 'Env Variables:'
	@printf "  ${YELLOW}CONTAINER_ENGINE${RESET}\tSet container engine, [*podman*, docker]\n"
	@printf "  ${YELLOW}BUILD_ENGINE${RESET}\t\tSet build engine, [*podman*, buildah, docker]\n"
	@printf "  ${YELLOW}SELINUX_ENABLED${RESET}\tEnable SELinux on containers, [*False*, True]\n"
	@printf "  ${YELLOW}LOCAL_SERVER_PORT${RESET}\tPort on which the local mkdocs server will run, [*8000*]\n"
	@echo ''
	@echo 'Targets:'
	@awk '/^[a-zA-Z\-_0-9]+:/ { \
		helpMessage = match(lastLine, /^## (.*)/); \
		if (helpMessage) { \
			helpCommand = substr($$1, 0, index($$1, ":")-1); \
			helpMessage = substr(lastLine, RSTART + 2, RLENGTH); \
			printf "  ${YELLOW}%-$(TARGET_MAX_CHAR_NUM)s${RESET}\t${GREEN}%s${RESET}\n", helpCommand, helpMessage; \
		} \
	} \
	{ lastLine = $$0 }' $(MAKEFILE_LIST)


envvar:
ifndef BUILD_ENGINE
	@$(eval export BUILD_ENGINE=podman build . -t)
else
ifeq ($(shell test "${BUILD_ENGINE}" == "podman" || test "${BUILD_ENGINE}" == "podman build . -t" && printf true), true)
	@$(eval export BUILD_ENGINE=podman build . -t)
else ifeq ($(shell test "${BUILD_ENGINE}" == "buildah" || test "${BUILD_ENGINE}" == "buildah build-using-dockerfile -t" && printf "true"), true)
	@$(eval export BUILD_ENGINE=buildah build-using-dockerfile -t)
else ifeq ($(shell test "${BUILD_ENGINE}" == "docker" || test "${BUILD_ENGINE}" == "docker build . -t" && printf "true"), true)
	@$(eval export BUILD_ENGINE=docker build . -t)
else
	@echo ${BUILD_ENGINE}
	@echo "Invalid value for BUILD_ENGINE ... exiting"
endif
endif

ifndef CONTAINER_ENGINE
	@$(eval CONTAINER_ENGINE=podman)
else
ifeq ($(shell test "$(CONTAINER_ENGINE)" = "podman" && printf true), true)
	@$(eval export CONTAINER_ENGINE=podman)
else ifeq ($(shell test "$(CONTAINER_ENGINE)" = "docker" && printf "true"), true)
	@$(eval export CONTAINER_ENGINE=docker)
else
	@echo ${CONTAINER_ENGINE}
	@echo "Invalid value for CONTAINER_ENGINE ... exiting"
endif
endif

ifndef DEBUG
	@$(eval export DEBUG=@)
else
ifeq ($(shell test "$(DEBUG)" = True  -o  \
									 "$(DEBUG)" = true && printf "true"), true)
	@$(eval export DEBUG=)
else
	@$(eval export DEBUG=@)
endif
endif

ifdef SELINUX_ENABLED
ifeq ($(shell test "$(SELINUX_ENABLED)" = True  -o  \
									 "$(SELINUX_ENABLED)" = true && printf "true"), true)
		@$(eval export SELINUX_ENABLED=,Z)
else
		@$(eval export SELINUX_ENABLED='')
endif
endif
	@echo

ifndef IMGTAG
	@$(eval export IMGTAG=localhost/kubevirt-user-guide)
else
ifeq ($(shell test $IMGTAG > /dev/null 2>&1 && printf "true"), true)
	@echo WARN: Using IMGTAG=$$IMGTAG
	@echo
else
	@$(eval export IMGTAG=localhost/kubevirt-user-guide)
endif
endif


## Build site. This target should only be used by Netlify and Prow
build: envvar
	@echo "${GREEN}Makefile: Build mkdocs site${RESET}"
	$(PYTHON) -m venv /tmp/venv
	. /tmp/venv/bin/activate
	$(PIP) install mkdocs mkdocs-awesome-nav mkdocs-htmlproofer-plugin mkdocs-material mkdocs-redirects
	@echo
	@echo '*** BEGIN cat mkdocs.yml ***'
	@cat mkdocs.yml
	@echo '*** END cat mkdocs.yml ***'
	mkdocs build -f mkdocs.yml -d site


## Build image localhost/kubevirt-user-guide
build_img: | envvar
	@echo "${GREEN}Makefile: Building Image ${RESET}"
	${DEBUG}if [ ! -e "./Dockerfile" ]; then \
	  IMAGE="`echo $${IMGTAG} | sed -e s#\'##g -e s#localhost\/## -e s#:latest##`";  \
		echo "Downloading Dockerfile file: https://raw.githubusercontent.com/kubevirt/project-infra/main/images/kubevirt-user-guide/Dockerfile"; \
	  if ! `curl -f -s https://raw.githubusercontent.com/kubevirt/project-infra/main/images/kubevirt-user-guide/Dockerfile -o ./Dockerfile`; then \
			echo "${RED}ERROR: Unable to curl Dockerfile... exiting!${RESET}"; \
			exit 2; \
		else \
			echo "${WHITE}Dockerfile file updated${RESET}"; \
			echo; \
			REMOTE=1; \
		fi; \
	else \
		IMAGE="`echo $${TAG} | sed -e s#\'##g -e s#localhost\/## -e s#:latest##`"; \
		echo "Using Dockerfile file: ./Dockerfile"; \
		echo "Be sure to add changes to upstream: kubevirt/project-infra/main/images/${IMGTAG}/Dockerfile"; \
		echo; \
	fi; \
	${CONTAINER_ENGINE} rmi ${IMGTAG} 2> /dev/null || echo -n; \
	${BUILD_ENGINE} ${IMGTAG}; \
	if [ "$${REMOTE}" ]; then rm -f Dockerfile > /dev/null 2>&1; fi


## Check external and internal links
check_links: | envvar stop
	@echo "${GREEN}Makefile: Check external and internal links${RESET}"
	${DEBUG}export IFS=$$'\n'; \
	${CONTAINER_ENGINE} run \
		-it \
		--rm \
		--name userguide \
		-v ${PWD}:/srv:ro${SELINUX_ENABLED} \
		-v /dev/null:/srv/Gemfile.lock \
		--mount type=tmpfs,destination=/srv/site \
		--workdir=/srv \
		${IMGTAG} \
		/bin/bash -c 'rake -- -u'
	@echo


## Check spelling on content
check_spelling: | envvar stop
	@echo "${GREEN}Makefile: Check spelling on site content${RESET}"
	${DEBUG}if [ ! -e "./yaspeller.json" ]; then \
		echo "${WHITE}Downloading Dictionary file: https://raw.githubusercontent.com/kubevirt/project-infra/main/images/yaspeller/.yaspeller.json${RESET}"; \
		if ! `curl -f -s https://raw.githubusercontent.com/kubevirt/project-infra/main/images/yaspeller/.yaspeller.json -o yaspeller.json`; then \
			echo "${RED}ERROR: Unable to curl yaspeller dictionary file... exiting!${RESET}"; \
			exit 2; \
		else \
			echo "${WHITE}Dictionary file updated${RESET}"; \
			echo; \
			REMOTE=1; \
		fi; \
	else \
		echo "YASPELLER file: ./yaspeller.json"; \
		echo "Be sure to add changes to upstream: kubevirt/project-infra/main/images/yaspeller/.yaspeller.json"; \
		echo; \
	fi; \
	if `jq -C  . yaspeller.json > /dev/null 2>&1`; then \
		${CONTAINER_ENGINE} run \
			-it \
			--rm \
			--name userguide \
			-v ${PWD}:/srv:ro${SELINUX_ENABLED} \
			-v ${PWD}/yaspeller.json:/srv/yaspeller.json:ro${SELINUX_ENABLED} \
			--workdir=/srv ${IMGTAG} \
			/bin/bash -c 'yaspeller -c /srv/yaspeller.json --only-errors --ignore-tags iframe,img,code,kbd,object,samp,script,style,var /srv' | sed -e 's/\/srv/./g'; \
	else \
		echo "${RED}ERROR: yaspeller dictionary file does not exist or is invalid json ${RESET}"; \
		exit 1; \
	fi; \
	if [ "$${REMOTE}" ]; then rm -f yaspeller.json > /dev/null 2>&1; fi


## Run site.  App available @ http://0.0.0.0:8000
run: | envvar stop
	@echo "${GREEN}Makefile: Run site${RESET}"
	${CONTAINER_ENGINE} run \
		-d \
		--name userguide \
		-p ${LOCAL_SERVER_PORT}:8000 \
		-v ${PWD}:/srv:ro${SELINUX_ENABLED} \
		-v /dev/null:/srv/Gemfile.lock:rw \
		--mount type=tmpfs,destination=/srv/site \
		${IMGTAG} \
		/bin/bash -c "mkdocs build -f /srv/mkdocs.yml && mkdocs serve -f /srv/mkdocs.yml -a 0.0.0.0:8000"
	@echo
	@echo "${AQUA}Makefile: Server now running at [http://localhost:$(LOCAL_SERVER_PORT)]${RESET}"
	@echo


## Run versioned site with mike using git worktrees (for testing versioning locally)
run_versioned: | envvar stop
	@echo "${GREEN}Makefile: Run versioned site with mike${RESET}"
	@echo "${YELLOW}Setting up git worktrees for version testing...${RESET}"
	# Clean up any existing worktrees
	${DEBUG}git worktree remove -f .worktrees/v1.7 2>/dev/null || true
	${DEBUG}rm -rf .worktrees 2>/dev/null || true
	${DEBUG}mkdir -p .worktrees
	# Create worktree for v1.7
	${DEBUG}git worktree add .worktrees/v1.7 upstream/release-v1.7-devel
	@echo "${YELLOW}Building versioned docs...${RESET}"
	# Run container with both main and v1.7 mounted
	${DEBUG}${CONTAINER_ENGINE} run \
		-it \
		--rm \
		--name userguide-versioned \
		-p ${LOCAL_SERVER_PORT}:8000 \
		-v ${PWD}:/srv/main:ro${SELINUX_ENABLED} \
		-v ${PWD}/.worktrees/v1.7:/srv/v1.7:ro${SELINUX_ENABLED} \
		--mount type=tmpfs,destination=/tmp/site \
		--workdir=/tmp/site \
		${IMGTAG} \
		/bin/bash -c ' \
			pip install mike mkdocs-static-i18n && \
			git config --global user.name "Local Test" && \
			git config --global user.email "test@local" && \
			git init && \
			cp -r /srv/v1.7/* . && \
			sed -i "/^site_favicon:/d" mkdocs.yml && \
			sed -i "/content.action.edit/a\\    - navigation.version" mkdocs.yml && \
			sed -i "/^extra:/a\\  version:\\n    provider: mike" mkdocs.yml && \
			bash hack/internationalize.sh . && \
			git add -A && git commit -q -m "v1.7" && \
			mike deploy --branch gh-pages --config-file mkdocs.yml v1.7 && \
			cp hack/internationalize.sh /tmp/int.sh && \
			find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} + && \
			cp -r /srv/main/* . && \
			mkdir -p hack i18n/es i18n/zh && \
			cp /tmp/int.sh hack/internationalize.sh && \
			sed -i "/  - awesome-nav/i\\  - i18n:\\n      docs_structure: folder\\n      languages:\\n        - locale: en\\n          name: English\\n          default: true\\n          link: /en/\\n        - locale: es\\n          name: Español\\n          link: /es/\\n        - locale: zh\\n          name: 中文\\n          link: /zh/" mkdocs.yml && \
			bash hack/internationalize.sh . && \
			git add -A && git commit -q -m "main" && \
			mike deploy --branch gh-pages --config-file mkdocs.yml latest main && \
			mike set-default --branch gh-pages latest && \
			mike serve --branch gh-pages -a 0.0.0.0:8000 \
		'
	@echo "${AQUA}Versioned site stopped. Cleaning up worktrees...${RESET}"
	${DEBUG}git worktree remove -f .worktrees/v1.7 2>/dev/null || true
	${DEBUG}rm -rf .worktrees 2>/dev/null || true


## Verify versioned build (check version content)
verify_versioned: | envvar
	@echo "${GREEN}Verifying version-specific content${RESET}"
	${DEBUG}${CONTAINER_ENGINE} run \
		-it \
		--rm \
		--name userguide-verify \
		-v ${PWD}:/srv/main:ro${SELINUX_ENABLED} \
		${IMGTAG} \
		/bin/bash -c 'head -12 /srv/main/docs/release_notes.md | grep -q "## v1.8.0" && echo "✓ Main branch has v1.8.0" || echo "✗ Main branch missing v1.8.0"'
	${DEBUG}git worktree add .worktrees/v1.7-verify upstream/release-v1.7-devel 2>/dev/null || true
	${DEBUG}${CONTAINER_ENGINE} run \
		-it \
		--rm \
		--name userguide-verify-v17 \
		-v ${PWD}/.worktrees/v1.7-verify:/srv/v1.7:ro${SELINUX_ENABLED} \
		${IMGTAG} \
		/bin/bash -c 'head -12 /srv/v1.7/docs/release_notes.md | grep -q "## v1.7.0" && echo "✓ v1.7 branch has v1.7.0" || echo "✗ v1.7 branch missing v1.7.0"'
	${DEBUG}git worktree remove -f .worktrees/v1.7-verify 2>/dev/null || true
	${DEBUG}rm -rf .worktrees 2>/dev/null || true
	@echo "${GREEN}Verification complete${RESET}"


## Container status
status: | envvar
	@echo "${GREEN}Makefile: Check image status${RESET}"
	${CONTAINER_ENGINE} ps
	@echo


## Stop site
stop: | envvar
	@echo "${GREEN}Makefile: Stop site${RESET}"
	${CONTAINER_ENGINE} rm -f userguide 2> /dev/null; echo
	@echo -n
