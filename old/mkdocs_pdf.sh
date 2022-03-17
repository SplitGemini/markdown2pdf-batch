#!/usr/bin/env bash
#
# Created on Fri Mar 11 2022
#
# Copyright (C) 2022 @SplitGemini
#

## make pdf docs from markdown

set -e
declare -r OWN_DIR=$(readlink -f "$(dirname $0)")

declare -r MAX_RETRY_NUM=3
declare -r NODE_LINK='https://nodejs.org/download/release/v16.14.0/node-v16.14.0-linux-x64.tar.xz'
declare -r FONT_LINK_BASE='https://github.com/adobe-fonts/source-han-sans/raw/release/Variable/WOFF2/OTF/'
declare -Ar FONT_NAMES=(
    ['sc']="Source Han Sans SC"
    ['tc']="Source Han Sans TC"
    ['hc']="Source Han Sans HC"
    ['jp']="Source Han Sans JP"
    ['kr']="Source Han Sans KR"
)
declare -Ar FONT_FILE_NAMES=(
    ['sc']="SourceHanSansSC-VF.otf.woff2"
    ['tc']="SourceHanSansTC-VF.otf.woff2"
    ['hc']="SourceHanSansHC-VF.otf.woff2"
    ['jp']="SourceHanSans-VF.otf.woff2"
    ['kr']="SourceHanSansK-VF.otf.woff2"
)
declare -Ar FONT_LINKS=(
    ['sc']="${FONT_LINK_BASE}${FONT_FILE_NAMES['sc']}"
    ['tc']="${FONT_LINK_BASE}${FONT_FILE_NAMES['ts']}"
    ['hc']="${FONT_LINK_BASE}${FONT_FILE_NAMES['hc']}"
    ['jp']="${FONT_LINK_BASE}${FONT_FILE_NAMES['jp']}"
    ['kr']="${FONT_LINK_BASE}${FONT_FILE_NAMES['kr']}"
)

#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< log functions
# colors
declare -r LOG_DEFAULT_COLOR="\033[0m"
declare -r LOG_ERROR_COLOR="\033[1;31m"
declare -r LOG_INFO_COLOR="\033[0;32m"
declare -r LOG_SUCCESS_COLOR="\033[1;32m"
declare -r LOG_WARN_COLOR="\033[1;33m"
declare -r LOG_DEBUG_COLOR="\033[1;34m"

# support multi arguments
log() {
    local log_level="$1"
    local log_color="$2"
    shift 2
    local log_text="$*"

    if [[ -z "${log_text}" ]]; then
        echo
        return 0
    fi
    echo -e "${log_color}[$(date +"%Y-%m-%d %H:%M:%S %z")] [${log_level}] ${log_text} ${LOG_DEFAULT_COLOR}"
    #echo -ne ${LOG_DEFAULT_COLOR} 1>/dev/null
    return 0
}

log_info() { log "INFO" "${LOG_INFO_COLOR}" "$@"; }
log_success() { log "SUCCESS" "${LOG_SUCCESS_COLOR}" "$@"; }
log_error() { log "ERROR" "${LOG_ERROR_COLOR}" "$@" >&2; }
log_warning() { log "WARNING" "${LOG_WARN_COLOR}" "$@" >&2; }
log_debug() {
    [ "$NDEBUG" = 'y' ] && return 0
    log "DEBUG" "${LOG_DEBUG_COLOR}" "$@"
}
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

# run all arguments with retry if fail
# if $1 = y, command output redirect to LOGFILE
# else run all argument with a $MAX_RETRY_NUM if run fail
retry_if_fail() {
    local retry_num=0
    while [ $retry_num -lt $MAX_RETRY_NUM ]; do
        "$@"
        if [ $? -gt 0 ]; then
            ((retry_num++))
            log_warning "run '$*' fail, retry $retry_num time"
            continue
        else
            break
        fi
    done
    if [ $retry_num -eq $MAX_RETRY_NUM ]; then
        log_error "reach max retry time:$MAX_RETRY_NUM, fail"
        return 1
    fi
}

# download a url file to WORKDIR with
# $1 download url link
# $2 output file
download() {
    local url=$1
    local output=$2
    if [ -s "${output}" ]; then
        log_info "'${output}' exists, skip download."
        return 0
    fi
    if [ -z "$url" ]; then
        log_error "url is empty"
        return 1
    fi
    if ! echo $url | grep -Eq '(https?|ftp)://.*'; then
        log_error "invalid url: $url"
        return 1
    fi
    # sharepoint add &download=1 argument at the end
    if echo $url | grep -q 'sharepoint' && ! echo $url | grep -q 'download=1'; then
        url="${url}&download=1"
    fi
    log_info "now start download '$(basename ${output})'"

    local cookie
    # get top domain name as cookie file name,
    # e.g., https://advantecho365-my.sharepoint.com/:u:/g/... -> advantecho365-my.sharepoint.com
    cookie=$(cut -d/ -f3 <<<$url)

    # -c cookie for download azure sharepoint needed
    retry_if_fail curl -c "${TEMP_DIR:?'temp dir empty'}/$cookie" -C - -L "${url}" -o "${output}"
    if [ $? -gt 0 ]; then
        log_error "download failed, check your internet, and url link and try again.\n    url:${url}"
        rm ${output} &>/dev/null || true
        return 1
    else
        log_success "download '$(basename ${output})' successfully"
        return 0
    fi
}

get_latest_pandoc() {
    local link output pandoc_path
    if ! curl https://github.com &>/dev/null; then
        log_warning "cannot access internet of web:github.com, check your proxy"
    fi
    log_info "get pandoc"
    link=$(curl -s https://api.github.com/repos/jgm/pandoc/releases/latest |
        grep "browser_download_url.*linux-amd64" |
        cut -d\" -f 4)
    if [ -z "$link" ]; then
        log_error "get link from padoc github fail"
        return 1
    fi
    # get name of package
    output=${link##*/}
    download $link $output || return 1
    pandoc_path="$(cut -d- -f 1,2 <<<$output)"/bin/pandoc
    tar -xf $output $pandoc_path
    mv $pandoc_path $BIN_DIR/
}

get_latest_wkhtmltopdf() {
    local link output
    if ! curl https://github.com &>/dev/null; then
        log_warning "cannot access internet of web:github.com, check your proxy"
    fi
    log_info "get wkhtmltopdf"
    # get VERSION_CODENAME
    . /etc/os-release
    # why not get latest release?
    # because not every release has binary build
    link=$(curl -s https://api.github.com/repos/wkhtmltopdf/wkhtmltopdf/releases |
        grep "browser_download_url.*$VERSION_CODENAME" | head -1 |
        cut -d\" -f4)
    if [ -z "$link" ]; then
        log_error "get link from wkhtmltopdf github release fail"
        return 1
    fi
    output=${link##*/}
    # here download is a deb file
    download $link $output || return 1
    # extract deb to wkhtmltopdf dir
    # why not install it? because it's not neccesarry and install need root permission but extract don't
    dpkg -x $output wkhtmltopdf
    # copy to bin
    mv "$(find wkhtmltopdf -type f -name wkhtmltopdf)" $BIN_DIR/
}

wkhtmltopdf_requires() {
    log_error "'wkhtmltopdf' requires some dependency packages, install them now, please enter passport"
    local prepend
    if [ $EUID -ne 0 ]; then
        prepend='sudo'
    fi
    $prepend apt update && $prepend apt install --no-install-recommends -y \
        libfreetype6 libjpeg-turbo8 libpng16-16 libssl1.1 libstdc++6 \
        libx11-6 libxcb1 libxext6 libxrender1 xfonts-75dpi xfonts-base zlib1g \
        ca-certificates fontconfig libc6
}

chrome_require() {
    log_error "'mermaid' requires some dependency packages, install them now, please enter passport"
    local prepend
    if [ $EUID -ne 0 ]; then
        prepend='sudo'
    fi
    $prepend apt update && $prepend apt install --no-install-recommends -y \
        ca-certificates fonts-liberation fonts-liberation2 fonts-noto-color-emoji \
        fonts-takao gconf-service libasound2 libatk-bridge2.0-0 libatk1.0-0 libc6 \
        libcairo2 libcups2 libdbus-1-3 libdrm2 libexpat1 libfontconfig1 libgbm-dev \
        libgbm1 libgcc1 libgconf-2-4 libgdk-pixbuf2.0-0 libglib2.0-0 libgtk-3-0 \
        libnspr4 libnss3 libpango-1.0-0 libpangocairo-1.0-0 libstdc++6 libx11-6 \
        libx11-xcb1 libxcb1 libxcomposite1 libxcursor1 libxdamage1 libxext6 libxfixes3 \
        libxi6 libxrandr2 libxrender1 libxshmfence1 libxss1 libxtst6 lsb-release wget \
        xdg-utils
}

get_mermaid() {
    # download $MERMAID_LINK mermaid.tar.gz || return 1
    # tar -xf mermaid.tar.gz -C $BIN_DIR
    mkdir -p $BIN_DIR/mermaid
    cp $OWN_DIR/*.json $BIN_DIR/mermaid
    pushd $BIN_DIR/mermaid &>/dev/null
    retry_if_fail npm ci || {
        log_error "do npm mermaid-cli fail"
        return 1
    }
    # check whether system can run chrome
    ldd "$(find $BIN_DIR/mermaid/node_modules/puppeteer/.local-chromium -name 'chrome' -print -quit)" |
        grep -q 'not found' && chrome_require
    popd &>/dev/null
}

get_node() {
    local node_name=${NODE_LINK##*/}
    if [ ! -d $BIN_DIR/${node_name%.tar.xz} ]; then
        download $NODE_LINK $node_name || return 1
        tar -xf $node_name -C $BIN_DIR
    fi

    export PATH="$BIN_DIR/${node_name%.tar.xz}/bin:$PATH"
}

get_css() {
    rsync -a $OWN_DIR/css/ $TEMP_DIR/css/
    rsync -au $OWN_DIR/fonts/ $TEMP_DIR/fonts/
    sed -i -e "s|@@CSS_FILE@@|$LANGUAGE|" -e "s|@@FONT@@|${FONT_NAMES[$LANGUAGE]}|" $CSS_PATH
}

get_font() {
    download ${FONT_LINKS[$LANGUAGE]} $TEMP_DIR/fonts/${FONT_FILE_NAMES[$LANGUAGE]}
}

# must run after get_css
#
install_font() {
    mkdir -p ~/.fonts/opentype/
    [ -e $TEMP_DIR/fonts/${FONT_FILE_NAMES[$LANGUAGE]} ] || get_font
    cp $TEMP_DIR/fonts/${FONT_FILE_NAMES[$LANGUAGE]} ~/.fonts/opentype/
    fc-cache -f
}

prepare() {
    [ -e $BIN_DIR/pandoc ] || {
        get_latest_pandoc || return 1
    }
    [ -e $BIN_DIR/wkhtmltopdf ] || {
        get_latest_wkhtmltopdf || return 1
    }

    # check whether can run wkhtmltopdf
    ldd $BIN_DIR/wkhtmltopdf | grep -q 'not found' && {
        wkhtmltopdf_requires || return 1
    }

    [ -d $BIN_DIR/mermaid ] || {
        get_mermaid || return 1
    }

    # node not exists, download one
    command -v node &>/dev/null || {
        get_node || return 1
    }
    # always update css
    get_css || return 1

    if [ -n "$LANGUAGE" ]; then
        get_font || return 1
        # if don't has chinese font, install one for it
        if [[ "$(fc-list :lang=zh)" =~ ^\s*$ ]]; then
            # m
            install_font || return 1
        fi
    fi

    # export PATH for direct usage
    export PATH="$BIN_DIR:$PATH"
}

un_mermaid() {
    local doc=$1
    local output=$2
    local png
    pushd $BIN_DIR/mermaid &>/dev/null || return 1
    # generate mermaid image
    # mermaid output will add '-1' '-2'... index suffix
    # --cssFile ./index.css
    npx mmdc -p puppeteer-config.json -i $doc -o $output
    local index=1
    # replace mermaid code with image
    while grep -Eq '```mermaid' $doc; do
        png=$(basename $doc)
        png=${png%.md}-${index}.png
        # run a js script to replace md content
        node -e "const fs = require('fs');
            fs.writeFileSync('$doc',
                    fs.readFileSync('$doc', 'utf8').
                            replace(/\`\`\`mermaid[\s\S]*?\`\`\`/,'![$png](./$png)'),
                    );"

        ((index++))
    done
    popd &>/dev/null || return 1
    #docker run --rm -v $OWN_DIR:/$OWN_DIR minlag/mermaid-cli -i $doc -o $output
}

do_pandoc() {
    local input=$1
    local output=$2
    local inputs
    pushd "$(dirname $input)" &>/dev/null || return 1
    #set -x
    if grep -Eq '^\[TOC\]' $input; then
        local html_header html toc_line_num
        # variables
        input_header="${input%.md}-header.md"
        input_body="${input%.md}-body.md"
        html_header="${input%.md}-header.html"
        html="${input%.md}.html"

        toc_line_num=$(sed -n -Ee "/^\[TOC\]$/=" $input)
        if [ $toc_line_num -ne 1 ]; then
            sed -n "1,$((toc_line_num - 1))p" $input >$input_header
            pandoc $input_header -o $html_header --css $CSS_PATH -t html5 --metadata-file \
                $OWN_DIR/pandoc-metadata.yml -s --from markdown+emoji
            inputs="$html_header"
        fi
        sed -n "$((toc_line_num + 1)),\$p" $input >$input_body

        pandoc $input_body -o $html --css $CSS_PATH -t html5 --metadata-file \
            $OWN_DIR/pandoc-metadata.yml -s --from markdown+emoji --toc
        inputs="$inputs $html"
    else
        local html
        html="${input%.md}.html"
        pandoc $input -o $html --css $CSS_PATH -t html5 --metadata-file \
            $OWN_DIR/pandoc-metadata.yml --from markdown+emoji -s
        inputs="$html"
    fi

    wkhtmltopdf --page-size A4 --margin-top 20 --margin-left 15 \
        --margin-right 15 --margin-bottom 10 --disable-smart-shrinking $inputs $output
    # --toc # -B header.html
    #set +x
    popd &>/dev/null || return 1
}

# recursively read docs dir and do make pdf for markdown
make_pdf() {
    local local_docs=$1
    local pdf_file docs_dir_name docs_dir
    docs_dir_name=$(basename $local_docs)
    # copy and sync a tmp docs dir
    rsync -rq --delete $local_docs/ $TEMP_DIR/$docs_dir_name/
    docs_dir="$TEMP_DIR/$docs_dir_name"
    while read -r entry; do
        if [ -d $entry ]; then # dir
            # make same struct of docs
            mkdir -p $PDF_OUT/${entry#"${docs_dir}"}
        elif [[ $entry =~ \.md$ ]]; then # md file
            # mermaid png image
            un_mermaid $entry ${entry%.md}.png
            pdf_file=${entry%.md}.pdf
            # pandoc to pdf
            do_pandoc ${entry} $PDF_OUT/${pdf_file#"${docs_dir}"}
        elif [[ $entry =~ \.xlsx$ ]]; then # xlsx file
            # just copy
            cp $entry $PDF_OUT/${entry#"${docs_dir}"}
        fi
    done <<<"$(find $docs_dir)"
}

usage() {
    echo \
        "make pdf for docs script
Usage: $0 [OPTIONS]

OPTIONS:
  * [-h|--help]: Print this
  * [-t|--tmp-dir]: Specified temp dir, auto create one by default.
  * [-o|--output]: Specified output dir for pdf, docs dir suffix with '-pdf' by default.
  * [-d|--docs]: Specified docs dir, 'docs' by default.
  * [-l|--language]: Specified language of font, select from 'sc'(Simplified Chinese),
        'tc'(Tranditional Chinese Taiwan), 'hc'(Tranditional Chinese - HongKong), 'jp'(Japanese),
        and 'kr'(Korean). Simplified Chinese by default.
  * [--prepare]: Prepare components but don't make pdf

Attentions:
    Sometimes maybe need root permission to install dependecies
"
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -h | --help)
            usage
            exit 0
            ;;
        -t | --tmp-dir)
            TEMP_DIR=$(readlink -f $2)
            if grep -q '\.' <<<$TEMP_DIR; then
                log_error "Because of Mermaid-cli's bug, path can't has '.' symbol." \
                    "Please change another path."
                exit 1
            fi
            shift
            ;;
        -d | --docs)
            DOCS=$(readlink -f $2)
            shift
            ;;
        -o | --output)
            PDF_OUT=$(readlink -f $2)
            shift
            ;;
        -l | --language)
            LANGUAGE=$2
            if ! grep -Eq "(?:^|\b)$LANGUAGE(?:$|\b)" <<<"${!FONT_NAMES[*]}"; then
                log_error "invalid language $LANGUAGE, please select from '$(echo ${!FONT_NAMES[*]} | tr ' ' ',')'"
                exit 1
            fi
            shift
            ;;
        -p | --prepare)
            PREPARE_ONLY=y
            ;;
        *)
            usage
            exit 2
            ;;
    esac

    shift
done

main() {
    # mermaid cli has bug to resolve path has '.' symbol, so temp dir can has '.'
    TEMP_DIR=${TEMP_DIR:-$(mktemp -d -p . build-docs-XXXXXXXX)}
    LANGUAGE=${LANGUAGE:-sc}

    BIN_DIR="$TEMP_DIR/bin"
    mkdir -p $BIN_DIR

    CSS_PATH="$TEMP_DIR/css/github.css"

    pushd $TEMP_DIR &>/dev/null || {
        log_error "pushd to $TEMP_DIR fail"
        exit 1
    }

    prepare || exit 1

    # if only prepare , skip make docs
    [ "$PREPARE_ONLY" = y ] && return 0

    DOCS=${DOCS:-./docs}
    if [ ! -d $DOCS ]; then
        log_error "docs: $DOCS is not a dir"
        exit 1
    fi
    PDF_OUT="${PDF_OUT:-$(dirname $DOCS)/$(basename $DOCS)-pdf}"
    mkdir -p $PDF_OUT
    make_pdf ${DOCS}
    # clean empty dirs
    find ${PDF_OUT:?pdf dir empty} -type d -exec rmdir --ignore-fail-on-non-empty {} \; &>/dev/null

    popd &>/dev/null || exit 1
}

main
