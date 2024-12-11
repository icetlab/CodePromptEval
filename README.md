## Context Experiment


#### Install dependenceies
```shell
# (optional) create a virtual environment
pip install virtualenv
python -m venv .<name_of_virtual_environment>
source .<name_of_virtual_environment>/bin/activate

# install packages
pip install -r requirements.txt
```

#### Run the pipeline
```shell
python pipeline.py --model <model> --version <version> --subset <subset> --language <python>
```

#### More info
```shell
# run for more information about the pipeline arguments
python pipeline.py --help

# (optional) to deactivate the virtual env
deactivate
```