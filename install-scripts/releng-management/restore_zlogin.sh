#!/bin/bash
set -euo pipefail

cd ../..

rm -f releng/airootfs/root/.zlogin
mv releng/airootfs/root/.zlogin.bak releng/airootfs/root/.zlogin
