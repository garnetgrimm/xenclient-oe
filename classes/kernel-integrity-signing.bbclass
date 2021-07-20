# No default! Either this or IMA_EVM_PRIVKEY/IMA_EVM_X509 have to be
# set explicitly in a local.conf before activating ima-evm-rootfs.
# To use the insecure (because public) example keys, use
# IMA_EVM_KEY_DIR = "${INTEGRITY_BASE}/data/debug-keys"
IMA_EVM_KEY_DIR ?= "IMA_EVM_KEY_DIR_NOT_SET"

# Private key for IMA signing. The default is okay when
# using the example key directory.
IMA_EVM_PRIVKEY ?= "${IMA_EVM_KEY_DIR}/privkey_ima.pem"

# Public part of certificates (used for both IMA and EVM).
# The default is okay when using the example key directory.
IMA_EVM_X509 ?= "${IMA_EVM_KEY_DIR}/x509_ima.der"

# Root CA to be compiled into the kernel, none by default.
IMA_EVM_ROOT_CA ?= "${IMA_EVM_KEY_DIR}/ima-local-ca.pem"

# Sign all regular files by default.
IMA_EVM_ROOTFS_SIGNED ?= ". -type f"
# Hash nothing by default.
IMA_EVM_ROOTFS_HASHED ?= ". -depth 0 -false"

ima_evm_sign_rootfs() {
    cd ${IMAGE_ROOTFS}
    # Sign file with private IMA key. EVM not supported at the moment.
    bbnote "IMA/EVM: signing files 'find ${IMA_EVM_ROOTFS_SIGNED}' with private key '${IMA_EVM_PRIVKEY}'"
    find ${IMA_EVM_ROOTFS_SIGNED} | xargs -d "\n" --no-run-if-empty --verbose evmctl ima_sign --key ${IMA_EVM_PRIVKEY}
    bbnote "IMA/EVM: hashing files 'find ${IMA_EVM_ROOTFS_HASHED}'"
    find ${IMA_EVM_ROOTFS_HASHED} | xargs -d "\n" --no-run-if-empty --verbose evmctl ima_hash
}

do_configure_append() {
    if ${@bb.utils.contains('DISTRO_FEATURES','ima','false','true',d)}; then
        return
    fi
    if ! grep -q '^CONFIG_IMA_TRUSTED_KEYRING=y' ${B}/.config ; then
        return
    fi
    if ! grep -q '^CONFIG_INTEGRITY_TRUSTED_KEYRING=y' ${B}/.config ; then
        return
    fi
    if ! grep -q '^CONFIG_SYSTEM_TRUSTED_KEYRING=y' ${B}/.config ; then
        return
    fi
    if [ -z "${IMA_EVM_ROOT_CA}" ]; then
        bbfatal "trusted keyring can only be used with a local CA. Please set IMA_EVM_ROOT_CA."
    fi
    sed -i -e '/CONFIG_SYSTEM_TRUSTED_KEYS[ =]/d' ${B}/.config
    echo "CONFIG_SYSTEM_TRUSTED_KEYS=\"${IMA_EVM_ROOT_CA}\"" >> \
        ${B}/.config
}

# Signing must run as late as possible in the do_rootfs task.
# To guarantee that, we append it to IMAGE_PREPROCESS_COMMAND in
# RecipePreFinalise event handler, this ensures it's the last
# function in IMAGE_PREPROCESS_COMMAND.
python ima_evm_sign_handler () {
    if not e.data or 'ima' not in e.data.getVar('DISTRO_FEATURES').split():
        return
    e.data.appendVar('IMAGE_INSTALL', ' ima-evm-keys')
    e.data.appendVar('IMAGE_PREPROCESS_COMMAND', ' ima_evm_sign_rootfs; ')
    e.data.appendVarFlag('do_rootfs', 'depends', ' ima-evm-utils-native:do_populate_sysroot')
}
addhandler ima_evm_sign_handler
ima_evm_sign_handler[eventmask] = "bb.event.RecipePreFinalise"
