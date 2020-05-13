# /bin/bash
# SUBDIRS := $(wildcard */.)
VAR_FILE := "variables.tf"
OUT_FILE := "outputs.tf"
define submake
	for d in $(ARGS);                  \
	do       \
		terraform init $$d; \
		terraform validate $$d; \
		terraform fmt -list=true -write=false -diff -check $$d; \
	done
endef

default:
	$(call submake,$@)

.PHONY: