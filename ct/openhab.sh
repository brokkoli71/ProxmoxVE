#!/usr/bin/env bash
 source <(curl -fsSL https://raw.githubusercontent.com/brokkoli71/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2025 tteck
# Author: tteck (tteckster)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://www.openhab.org/

APP="openHAB"
var_tags="${var_tags:-automation}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-8}"
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
    if [[ ! -f /etc/apt/sources.list.d/openhab.list ]]; then
        msg_error "No ${APP} Installation Found!"
        exit
    fi
    msg_info "Updating ${APP} LXC"
    $STD apt-get update
    $STD apt-get -y upgrade
    msg_ok "Updated Successfully"
    exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using one of the following URLs:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}https://${IP}:8443${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8080${CL}"
