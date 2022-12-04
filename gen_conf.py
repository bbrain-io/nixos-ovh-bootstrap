import os
import argparse
from pathlib import Path
from jinja2 import Environment, FileSystemLoader


def write_template(env: Environment, path: Path, template_name: str):
    template = env.get_template(template_name)
    out_path: Path = path / template_name

    if out_path.suffix == ".j2":
        out_path = out_path.with_suffix("")

    content = template.render(**os.environ)
    out_path.write_text(content)


parser = argparse.ArgumentParser()
parser.add_argument("-p", "--path", default="/etc/nixos", type=Path)
parser.add_argument("-t", "--template", default=None, required=False)
args = parser.parse_args()

env = Environment(
    loader=FileSystemLoader("templates/"),
    trim_blocks=True,
    lstrip_blocks=True,
)

if args.template is not None:
    write_template(env, args.path, args.template)
else:
    for template_name in env.list_templates():
        write_template(env, args.path, template_name)
