#!/bin/bash

set -eu

/usr/bin/nginx -t

if /usr/bin/systemctl is-active --quiet nginx.service; then
	/usr/bin/systemctl reload nginx.service
fi
