#!/usr/bin/env bash
 source <(curl -fsSL https://raw.githubusercontent.com/brokkoli71/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2025 tteck
# Author: tteck (tteckster)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/bastienwirtz/homer

APP="Homer"
var_tags="${var_tags:-dashboard}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-512}"
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
    if [[ ! -d /opt/homer ]]; then
        msg_error "No ${APP} Installation Found!"
        exit
    fi
    msg_info "Stopping ${APP}"
    systemctl stop homer
    msg_ok "Stopped ${APP}"

    msg_info "Backing up assets directory"
    cd ~
    mkdir -p assets-backup
    cp -R /opt/homer/assets/. assets-backup
    msg_ok "Backed up assets directory"

    msg_info "Updating ${APP}"
    rm -rf /opt/homer/*
    cd /opt/homer
    curl -fsSL "https://github.com/bastienwirtz/homer/releases/latest/download/homer.zip" -o $(basename "https://github.com/bastienwirtz/homer/releases/latest/download/homer.zip")
    $STD unzip homer.zip
    msg_ok "Updated ${APP}"

    msg_info "Restoring assets directory"
    cd ~
    cp -Rf assets-backup/. /opt/homer/assets/
    msg_ok "Restored assets directory"

    msg_info "Cleaning"
    rm -rf assets-backup /opt/homer/homer.zip
    msg_ok "Cleaned"

    msg_info "Starting ${APP}"
    systemctl start homer
    msg_ok "Started ${APP}"
    msg_ok "Updated Successfully"
    exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8010${CL}"
