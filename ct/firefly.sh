#!/usr/bin/env bash
 source <(curl -fsSL https://raw.githubusercontent.com/brokkoli71/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2025 community-scripts ORG
# Author: quantumryuu | Co-Author: Slaviša Arežina (tremor021)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://firefly-iii.org/

APP="Firefly"
var_tags="${var_tags:-finance}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-1024}"
var_disk="${var_disk:-2}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -d /opt/firefly ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi
  RELEASE=$(curl -fsSL https://api.github.com/repos/firefly-iii/firefly-iii/releases/latest | grep "tag_name" | awk '{print substr($2, 3, length($2)-4)}')
  if [[ ! -f /opt/${APP}_version.txt ]] || [[ "${RELEASE}" != "$(cat /opt/${APP}_version.txt)" ]]; then
    msg_info "Stopping Apache2"
    systemctl stop apache2
    msg_ok "Stopped Apache2"

    msg_info "Updating ${APP} to v${RELEASE}"
    cp /opt/firefly/.env /opt/.env
    cp -r /opt/firefly/storage /opt/storage
    cd /opt
    curl -fsSL "https://github.com/firefly-iii/firefly-iii/releases/download/v${RELEASE}/FireflyIII-v${RELEASE}.tar.gz" -o $(basename "https://github.com/firefly-iii/firefly-iii/releases/download/v${RELEASE}/FireflyIII-v${RELEASE}.tar.gz")
    tar -xzf FireflyIII-v${RELEASE}.tar.gz -C /opt/firefly --exclude='storage'
    cp /opt/.env /opt/firefly/.env
    cp -r /opt/storage /opt/firefly/storage
    cd /opt/firefly
    chown -R www-data:www-data /opt/firefly
    chmod -R 775 /opt/firefly/storage
    $STD php artisan migrate --seed --force
    $STD php artisan cache:clear
    $STD php artisan view:clear
    $STD php artisan firefly-iii:upgrade-database
    $STD php artisan firefly-iii:laravel-passport-keys
    echo "${RELEASE}" >"/opt/${APP}_version.txt"
    msg_ok "Updated ${APP} to v${RELEASE}"

    msg_info "Starting Apache2"
    systemctl start apache2
    msg_ok "Started Apache2"

    msg_info "Cleaning up"
    rm -rf /opt/FireflyIII-v${RELEASE}.tar.gz
    msg_ok "Cleaned"
    msg_ok "Updated Successfully"
  else
    msg_ok "No update required. ${APP} is already at v${RELEASE}."
  fi
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}${CL}"
