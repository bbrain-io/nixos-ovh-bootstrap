import os
import argparse
from pathlib import Path
from jinja2 import Environment, FileSystemLoader

parser = argparse.ArgumentParser()
parser.add_argument("template")
parser.add_argument("destination")
args = parser.parse_args()

env = Environment(
    loader=FileSystemLoader("templates/"),
    trim_blocks=True,
    lstrip_blocks=True,
)
template = env.get_template(args.template)

out = Path(args.destination)
content = template.render(**os.environ)
out.write_text(content)
