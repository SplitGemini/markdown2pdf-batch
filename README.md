# 生成PDF文档

运行`./mkdocs_pdf.sh`生成为docs文件夹的所有md生成pdf文件，放在pdf文件夹内

参数：

* `[-h|--help]`: 打印帮助
* `[-d|--docs]`: 指定md文件夹，默认为docs
* `[-t|--tmp-dir]`: 指定缓存文件夹，默认在改目录生成一个build-docs-前缀的目录

```shell
# 为docs文件夹生成pdf
./mkdocs_pdf.sh

# 为ppp文件夹生成pdf
./mkdocs_pdf.sh -d ppp

# 指定缓存目录，多次运行节省下载过程
./mkdocs_pdf.sh -t build-docs-xxxxxx
#
```

*该脚本会联网下载工具，请确保代理已连接，缺乏必须组件时可能需要*
