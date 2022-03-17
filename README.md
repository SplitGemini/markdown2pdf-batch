# Convert markdown to pdf in batch

It is a node script for convert all markdown(.md) docs in a directory to pdf, and reserve dir structure. It use [shd101wyy/mume](https://github.com/shd101wyy/mume) to complete the conversion process.

## Usage

`npm i` first

for script index.js

Arguments:

* `[-d|--docs]`: md dir, mandatory.
* `[-o|--output]`: pdf output dir, md dir suffix with '-pdf' by default.

## Example

```shell
# output to docs-pdf
node index.js --docs docs
```

## Container

recommand use `docker run -w $(pwd) -v $(pwd):$(pwd) -u $(id -u):$(id -g) --rm guoh27/jelina:md2pdf <Arguments>` run container

example: `docker run -w $(pwd) -v $(pwd):$(pwd) -u $(id -u):$(id -g) --rm guoh27/jelina:md2pdf --docs tests`

## Reference

[shd101wyy/mume](https://github.com/shd101wyy/mume)

## Old

Old dir stores bash script that use pandoc and wkhtmltopdf to convert pdf, using these tools instead of memu is too silly for me.

It is a bash script for convert all markdown(.md) docs in a directory to pdf, and reserve dir structure. It use [pandoc](https://github.com/jgm/pandoc), [mermaid-cli](https://github.com/mermaid-js/mermaid-cli) and [wkhtmltopdf](https://github.com/wkhtmltopdf/wkhtmltopdf) to complete the conversion process.
