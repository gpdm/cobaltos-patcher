#!/bin/sh

xorriso \
  -outdev cobaltos-patcher.iso -blank as_needed \
  -joliet on \
  -map rpms /rpms \
  -map cobaltos-patcher.sh /cobaltos-patcher.sh \
  -volid "COBALTOS_PATCHER"


