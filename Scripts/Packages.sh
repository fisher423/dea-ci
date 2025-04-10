#!/bin/bash

#安装和更新软件包
UPDATE_PACKAGE() {
	local PKG_NAME=$1
	local PKG_REPO=$2
	local PKG_BRANCH=$3
	local PKG_SPECIAL=$4
	local CUSTOM_NAMES=($5)  # 第5个参数为自定义名称列表
	local REPO_NAME=$(echo $PKG_REPO | cut -d '/' -f 2)

	echo " "

	# 将 PKG_NAME 加入到需要查找的名称列表中
	if [ ${#CUSTOM_NAMES[@]} -gt 0 ]; then
		CUSTOM_NAMES=("$PKG_NAME" "${CUSTOM_NAMES[@]}")  # 将 PKG_NAME 添加到自定义名称列表的开头
	else
		CUSTOM_NAMES=("$PKG_NAME")  # 如果没有自定义名称，则只使用 PKG_NAME
	fi

	# 删除本地可能存在的不同名称的软件包
	for NAME in "${CUSTOM_NAMES[@]}"; do
		# 查找匹配的目录
		echo "Searching directory: $NAME"
		local FOUND_DIRS=$(find ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "*$NAME*" 2>/dev/null)

		# 删除找到的目录
		if [ -n "$FOUND_DIRS" ]; then
			echo "$FOUND_DIRS" | while read -r DIR; do
				rm -rf "$DIR"
				echo "Deleted directory: $DIR"
			done
		else
			echo "No directories found matching name: $NAME"
		fi
	done

	# 克隆 GitHub 仓库
	git clone --depth=1 --single-branch --branch $PKG_BRANCH "https://github.com/$PKG_REPO.git"

	# 处理克隆的仓库
	if [[ $PKG_SPECIAL == "pkg" ]]; then
		find ./$REPO_NAME/*/ -maxdepth 3 -type d -iname "*$PKG_NAME*" -prune -exec cp -rf {} ./ \;
		rm -rf ./$REPO_NAME/
	elif [[ $PKG_SPECIAL == "name" ]]; then
		mv -f $REPO_NAME $PKG_NAME
	fi
}

# 调用示例
# UPDATE_PACKAGE "OpenAppFilter" "destan19/OpenAppFilter" "master" "" "custom_name1 custom_name2"
#这样会把原有的open-app-filter，luci-app-appfilter，oaf相关组件删除，不会出现coremark错误。
#UPDATE_PACKAGE "open-app-filter" "destan19/OpenAppFilter" "master" "" "luci-app-appfilter oaf"

# UPDATE_PACKAGE "包名" "项目地址" "项目分支" "pkg/name，可选，pkg为从大杂烩中单独提取包名插件；name为重命名为包名"
UPDATE_PACKAGE "argon" "sbwml/luci-theme-argon" "openwrt-24.10"

UPDATE_PACKAGE "homeproxy" "VIKINGYFY/homeproxy" "main"
UPDATE_PACKAGE "nikki" "nikkinikki-org/OpenWrt-nikki" "main"
#UPDATE_PACKAGE "openclash" "vernesong/OpenClash" "dev" "pkg"
#UPDATE_PACKAGE "passwall" "xiaorouji/openwrt-passwall" "main" "pkg"
#UPDATE_PACKAGE "ssr-plus" "fw876/helloworld" "master"

#UPDATE_PACKAGE "alist" "sbwml/luci-app-alist" "main"
#UPDATE_PACKAGE "mosdns" "sbwml/luci-app-mosdns" "v5"
UPDATE_PACKAGE "luci-app-store" "linkease/istore" "main"
UPDATE_PACKAGE "luci-app-dockerman" "lisaac/luci-app-dockerman" "master"
UPDATE_PACKAGE "luci-app-lucky" "sirpdboy/luci-app-lucky" "main"
UPDATE_PACKAGE "luci-app-timecontrol" "sirpdboy/luci-app-timecontrol" "main"
UPDATE_PACKAGE "luci-app-wol" "VIKINGYFY/packages" "main" "pkg"
UPDATE_PACKAGE "luci-app-gecoosac" "lwb1978/openwrt-gecoosac" "main"
#UPDATE_PACKAGE "luci-app-tailscale" "asvow/luci-app-tailscale" "main"


#UPDATE_PACKAGE "lazyoop" "lazyoop/networking-artifact" "main"

UPDATE_PACKAGE "luci-app-daed" "QiuSimons/luci-app-daed" "master"
UPDATE_PACKAGE "luci-app-ddns-go" "sirpdboy/luci-app-ddns-go" "main"
UPDATE_PACKAGE "luci-app-pushbot" "zzsj0928/luci-app-pushbot" "master"

if [[ $WRT_REPO != *"immortalwrt"* ]]; then
	UPDATE_PACKAGE "qmi-wwan" "immortalwrt/wwan-packages" "master" "pkg"
fi

#更新软件包版本
UPDATE_VERSION() {
	local PKG_NAME=$1
	local PKG_MARK=${2:-not}
	local PKG_FILES=$(find ./ ../feeds/packages/ -maxdepth 3 -type f -wholename "*/$PKG_NAME/Makefile")

	echo " "

	if [ -z "$PKG_FILES" ]; then
		echo "$PKG_NAME not found!"
		return
	fi

	echo "$PKG_NAME version update has started!"

	for PKG_FILE in $PKG_FILES; do
		local PKG_REPO=$(grep -Pho 'PKG_SOURCE_URL:=https://.*github.com/\K[^/]+/[^/]+(?=.*)' $PKG_FILE | head -n 1)
		local PKG_VER=$(curl -sL "https://api.github.com/repos/$PKG_REPO/releases" | jq -r "map(select(.prerelease|$PKG_MARK)) | first | .tag_name")
		local NEW_VER=$(echo $PKG_VER | sed "s/.*v//g; s/_/./g")
		local NEW_HASH=$(curl -sL "https://codeload.github.com/$PKG_REPO/tar.gz/$PKG_VER" | sha256sum | cut -b -64)
		local OLD_VER=$(grep -Po "PKG_VERSION:=\K.*" "$PKG_FILE")

		echo "$OLD_VER $PKG_VER $NEW_VER $NEW_HASH"

		if [[ $NEW_VER =~ ^[0-9].* ]] && dpkg --compare-versions "$OLD_VER" lt "$NEW_VER"; then
			sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=$NEW_VER/g" "$PKG_FILE"
			sed -i "s/PKG_HASH:=.*/PKG_HASH:=$NEW_HASH/g" "$PKG_FILE"
			echo "$PKG_FILE version has been updated!"
		else
			echo "$PKG_FILE version is already the latest!"
		fi
	done
}

#UPDATE_VERSION "软件包名" "测试版，true，可选，默认为否"
UPDATE_VERSION "sing-box"
UPDATE_VERSION "tailscale"

update_feeds() {
    # 删除注释行
    sed -i '/^#/d' "$BUILD_DIR/$FEEDS_CONF"

    # 检查并添加 small-package 源
    if ! grep -q "small-package" "$BUILD_DIR/$FEEDS_CONF"; then
        # 确保文件以换行符结尾
        [ -z "$(tail -c 1 "$BUILD_DIR/$FEEDS_CONF")" ] || echo "" >>"$BUILD_DIR/$FEEDS_CONF"
        echo "src-git small8 https://github.com/kenzok8/small-package" >>"$BUILD_DIR/$FEEDS_CONF"
    fi

    # 添加bpf.mk解决更新报错
    if [ ! -f "$BUILD_DIR/include/bpf.mk" ]; then
        touch "$BUILD_DIR/include/bpf.mk"
    fi

    # 切换nss-packages源
    #if grep -q "nss_packages" "$BUILD_DIR/$FEEDS_CONF"; then
    #    sed -i '/nss_packages/d' "$BUILD_DIR/$FEEDS_CONF"
    #    echo "src-git nss_packages https://github.com/ZqinKing/nss-packages.git" >>"$BUILD_DIR/$FEEDS_CONF"
    #fi

    # 更新 feeds
    ./scripts/feeds clean
    ./scripts/feeds update -a
}

remove_unwanted_packages() {
    local luci_packages=(
        "luci-app-passwall" "luci-app-smartdns" "luci-app-ddns-go" "luci-app-rclone"
        "luci-app-ssr-plus" "luci-app-vssr" "luci-theme-argon" "luci-app-daed" "luci-app-dae"
        "luci-app-alist" "luci-app-argon-config" "luci-app-homeproxy" "luci-app-haproxy-tcp"
        "luci-app-openclash" "luci-app-mihomo" "luci-app-appfilter"
    )
    local packages_net=(
        "haproxy" "xray-core" "xray-plugin" "dns2socks" "alist" "hysteria"
        "smartdns" "mosdns" "adguardhome" "ddns-go" "naiveproxy" "shadowsocks-rust"
        "sing-box" "v2ray-core" "v2ray-geodata" "v2ray-plugin" "tuic-client"
        "chinadns-ng" "ipt2socks" "tcping" "trojan-plus" "simple-obfs"
        "shadowsocksr-libev" "dae" "daed" "mihomo" "geoview" "tailscale" "open-app-filter"
    )
    local small8_packages=(
        "ppp" "firewall" "dae" "daed" "daed-next" "libnftnl" "nftables" "dnsmasq"
    )

    for pkg in "${luci_packages[@]}"; do
        \rm -rf ./feeds/luci/applications/$pkg
        \rm -rf ./feeds/luci/themes/$pkg
    done

    for pkg in "${packages_net[@]}"; do
        \rm -rf ./feeds/packages/net/$pkg
    done

    for pkg in "${small8_packages[@]}"; do
        \rm -rf ./feeds/small8/$pkg
    done

    if [[ -d ./package/istore ]]; then
        \rm -rf ./package/istore
    fi

    if grep -q "nss_packages" "$BUILD_DIR/$FEEDS_CONF"; then
        local nss_packages_dirs=(
            "$BUILD_DIR/feeds/luci/protocols/luci-proto-quectel"
            "$BUILD_DIR/feeds/packages/net/quectel-cm"
            "$BUILD_DIR/feeds/packages/kernel/quectel-qmi-wwan"
        )
        for dir in "${nss_packages_dirs[@]}"; do
            if [[ -d "$dir" ]]; then
                \rm -rf "$dir"
            fi
        done
    fi

    # 临时放一下，清理脚本
    if [ -d "$BUILD_DIR/target/linux/qualcommax/base-files/etc/uci-defaults" ]; then
        find "$BUILD_DIR/target/linux/qualcommax/base-files/etc/uci-defaults/" -type f -name "99*.sh" -exec rm -f {} +
    fi
}

update_golang() {
    if [[ -d ./feeds/packages/lang/golang ]]; then
        \rm -rf ./feeds/packages/lang/golang
        git clone --depth 1 $GOLANG_REPO -b $GOLANG_BRANCH ./feeds/packages/lang/golang
    fi
}

install_small8() {
    ./scripts/feeds install -p small8 -f xray-core xray-plugin dns2tcp dns2socks haproxy hysteria \
        naiveproxy shadowsocks-rust sing-box v2ray-core v2ray-geodata v2ray-geoview v2ray-plugin \
        tuic-client chinadns-ng ipt2socks tcping trojan-plus simple-obfs shadowsocksr-libev \
        luci-app-passwall alist luci-app-alist smartdns luci-app-smartdns v2dat mosdns luci-app-mosdns \
        adguardhome luci-app-adguardhome ddns-go luci-app-ddns-go taskd luci-lib-xterm luci-lib-taskd \
        luci-app-store quickstart luci-app-quickstart luci-app-istorex luci-app-cloudflarespeedtest \
        luci-theme-argon netdata luci-app-netdata lucky luci-app-lucky luci-app-openclash luci-app-homeproxy \
        luci-app-amlogic nikki luci-app-nikki tailscale luci-app-tailscale oaf open-app-filter luci-app-oaf \
        easytier luci-app-easytier accesscontrol luci-app-accesscontrol turboacc luci-app-turboacc
}



rm -rf small && git clone https://github.com/kenzok8/small small
rm -rf small/{luci-app-bypass,v2ray-geodata,luci-app-fchomo}
#不编译xray-core
sed -i 's/+xray-core//' small/luci-app-passwall2/Makefile

#删除官方的默认插件
rm -rf ../feeds/luci/applications/luci-app-{passwall*,mosdns,dockerman,dae*,bypass*}
rm -rf ../feeds/packages/net/{shadowsocks-rust,shadowsocksr-libev,xray*,v2ray*,dae*,sing-box,geoview,ddns-go,mosdns}

#更新golang为最新版
rm -rf ../feeds/packages/lang/golang
git clone -b 24.x https://github.com/sbwml/packages_lang_golang ../feeds/packages/lang/golang

#增强版v2ray-geodata
#git clone https://github.com/sbwml/v2ray-geodata
#sed -i 's/geoip-only-cn-private.dat/geoip.dat/g' ./v2ray-geodata/Makefile

cp -r $GITHUB_WORKSPACE/package/* ./

#coremark修复
sed -i 's/mkdir \$(PKG_BUILD_DIR)\/\$(ARCH)/mkdir -p \$(PKG_BUILD_DIR)\/\$(ARCH)/g' ../feeds/packages/utils/coremark/Makefile

argon_css_file=$(find ./luci-theme-argon/ -type f -name "cascade.css")
#修改字体
sed -i "/^.main .main-left .nav li a {/,/^}/ { /font-weight: bolder/d }" $argon_css_file
sed -i '/^\[data-page="admin-system-opkg"\] #maincontent>.container {/,/}/ s/font-weight: 600;/font-weight: normal;/' $argon_css_file
