CHART_REPO := http://jenkins-x-chartmuseum:8080
NAME := springone-app
OS := $(shell uname)

CHARTMUSEUM_CREDS_USR := $(shell cat /builder/home/basic-auth-user.json)
CHARTMUSEUM_CREDS_PSW := $(shell cat /builder/home/basic-auth-pass.json)

init:
	helm init --client-only

setup: init
	helm repo add jenkins-x http://chartmuseum.jenkins-x.io
	helm repo add zeebe http://helm.zeebe.io
	helm repo add releases ${CHART_REPO}

build: clean setup
	helm dependency build springone-app
	helm lint springone-app

install: clean build
	helm upgrade ${NAME} springone-app --install

upgrade: clean build
	helm upgrade ${NAME} springone-app --install

delete:
	helm delete --purge ${NAME} springone-app

clean:
	rm -rf springone-app/charts
	rm -rf springone-app/${NAME}*.tgz
	rm -rf springone-app/requirements.lock

release: clean build
ifeq ($(OS),Darwin)
	sed -i "" -e "s/version:.*/version: $(VERSION)/" springone-app/Chart.yaml

else ifeq ($(OS),Linux)
	sed -i -e "s/version:.*/version: $(VERSION)/" springone-app/Chart.yaml
else
	exit -1
endif
	helm package springone-app
	curl --fail -u $(CHARTMUSEUM_CREDS_USR):$(CHARTMUSEUM_CREDS_PSW) --data-binary "@$(NAME)-$(VERSION).tgz" $(CHART_REPO)/api/charts
	rm -rf ${NAME}*.tgz
	jx step changelog  --verbose --version $(VERSION) --rev $(PULL_BASE_SHA)
