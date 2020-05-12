SUBDIRS := $(wildcard */.)
VAR_FILE := "variables.tf"
OUT_FILE := "outputs.tf"
define submake
	for d in $(ARGS);                  \
	do       \
		[ -f $$d$(VAR_FILE) ] && echo exists || echo $$d$(VAR_FILE) not exists; exit 1; \
		[ -f $$d$(OUT_FILE) ] && echo exists || echo $$d$(OUT_FILE) not exists;\
		terraform init $$d; \
		terraform validate $$d; \
		terraform fmt -list=true -write=false -diff -check $$d; \
	done
endef

default:
	$(call submake,$@)

.PHONY: all install $(SUBDIRS)