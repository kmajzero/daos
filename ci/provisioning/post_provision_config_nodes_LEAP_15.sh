#!/bin/bash

REPOS_DIR=/etc/dnf/repos.d
DISTRO_NAME=leap15
LSB_RELEASE=lsb-release
EXCLUDE_UPGRADE=fuse,fuse-libs,fuse-devel,mercury,daos,daos-\*
DNF_REPO_ARGS="--disablerepo=*"

bootstrap_dnf() {
    time zypper --non-interactive install dnf
    rm -rf "$REPOS_DIR"
    ln -s ../zypp/repos.d "$REPOS_DIR"
}

group_repo_post() {
    if [ -n "$DAOS_STACK_GROUP_REPO" ]; then
        rpm --import \
            "${REPOSITORY_URL}${DAOS_STACK_GROUP_REPO%/*}/opensuse-15.2-devel-languages-go-x86_64-proxy/repodata/repomd.xml.key"
    fi
}

distro_custom() {
    # monkey-patch lua-lmod
    if ! grep MODULEPATH=".*"/usr/share/modules /etc/profile.d/lmod.sh; then \
        sed -e '/MODULEPATH=/s/$/:\/usr\/share\/modules/'                     \
               /etc/profile.d/lmod.sh;                                        \
    fi

    # Add Avocado PR
    time dnf config-manager --add-repo \
             https://build.hpdd.intel.com/job/daos-stack/job/python-avocado/job/PR-3/lastSuccessfulBuild/artifact/artifacts/leap15
    disable_gpg_check "build.hpdd.intel.com_job_daos-stack_job_python-avocado_job_PR-3_lastSuccessfulBuild_artifact_artifacts_leap15"

}
post_provision_config_nodes() {
    bootstrap_dnf

    # Reserve port ranges 31416-31516 for DAOS and CART servers
    echo 31416-31516 > /proc/sys/net/ipv4/ip_local_reserved_ports

    if $CONFIG_POWER_ONLY; then
        rm -f $REPOS_DIR/*.hpdd.intel.com_job_daos-stack_job_*_job_*.repo
        time dnf -y erase fio fuse ior-hpc mpich-autoload               \
                     ompi argobots cart daos daos-client dpdk      \
                     fuse-libs libisa-l libpmemobj mercury mpich   \
                     openpa pmix protobuf-c spdk libfabric libpmem \
                     libpmemblk munge-libs munge slurm             \
                     slurm-example-configs slurmctld slurm-slurmmd
    fi

    time dnf repolist
    add_group_repo
    add_local_repo
    time dnf repolist

    if [ -n "$INST_REPOS" ]; then
        local repo
        for repo in $INST_REPOS; do
            branch="master"
            build_number="lastSuccessfulBuild"
            if [[ $repo = *@* ]]; then
                branch="${repo#*@}"
                repo="${repo%@*}"
                if [[ $branch = *:* ]]; then
                    build_number="${branch#*:}"
                    branch="${branch%:*}"
                fi
            fi
            local repo_url="${JENKINS_URL}"job/daos-stack/job/"${repo}"/job/"${branch//\//%252F}"/"${build_number}"/artifact/artifacts/$DISTRO_NAME/
            dnf config-manager --add-repo="${repo_url}"
            disable_gpg_check "$repo_url"
            # TODO: this should be per repo in the above loop
            if [ -n "$INST_REPOS" ]; then
                DNF_REPO_ARGS+=" --enablerepo=build.hpdd.intel.com_job_daos-stack*"
            fi
        done
    fi
    if [ -n "$INST_RPMS" ]; then
        # shellcheck disable=SC2086
        time dnf -y erase $INST_RPMS
    fi
    rm -f /etc/profile.d/openmpi.sh
    rm -f /tmp/daos_control.log
    time dnf -y install $LSB_RELEASE
    # shellcheck disable=SC2086
    if [ -n "$INST_RPMS" ] &&
       ! time dnf -y $DNF_REPO_ARGS install $INST_RPMS; then
        rc=${PIPESTATUS[0]}
        dump_repos
        exit "$rc"
    fi

    distro_custom

    # now make sure everything is fully up-to-date
    if ! time dnf -y upgrade \
                  --exclude "$EXCLUDE_UPGRADE"; then
        dump_repos
        exit 1
    fi

    # Install python3 Avocado also
    if ! time dnf -y install \
        python{2,3}-avocado{,-plugins-{output-html,varianter-yaml-to-mux}}; then
        dump_repos
        exit 1
    fi

    exit 0
}
