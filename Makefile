# /bin/bash
# SUBDIRS := $(wildcard */.)
VAR_FILE := "variables.tf"
OUT_FILE := "outputs.tf"
define submake
	for d in $(ARGS);                  \
	do       \
		[ -f $$d$(VAR_FILE) ] && echo "check"; || echo $$d$(VAR_FILE) does not exist; exit 1; \
		[ -f $$d$(OUT_FILE) ] && echo "check"; || echo "$$d$(OUT_FILE) does not exist"; exit 1; \
		terraform init $$d; \
		terraform validate $$d; \
		terraform fmt -list=true -write=false -diff -check $$d; \
	done
endef

default:
	$(call submake,$@)

.PHONY: