## CodePromptEval: Evaluating the impact of prompt programming on code generation

This repository contains a dataset, CodePromptEval, based on the CoderEval Python dataset's functions (Yu et al. (2024)). CodePromptEval consists of 7,072 prompts based on 221 prompts for code-generation tasks, and each prompt implements 32 unique combinations of prompt techniques. The prompt techniques we cover are Few-shot learning, Persona, Chain-of-Thought, Function Signature (context), and List of Packages (context).

In addition, we provide the replication package of the study _"The Impact of Prompt Programming on Function-Level Code Generation"_ by Khojah et al. (2024). The replication package contains the original CoderEval, the additional tests and few-shot examples that we added to CoderEval, the scripts that we used to construct and evaluate CodePromptEval on five LLMs (GPT-3.5, GPT-4o, Llama3-70B, Llama2-7B, and Mistral), as well as the LLMs output with the generated functions and the evaluation results.

**To cite this work:**
```bibtex
@article{khojah2024impact,
  title={{The Impact of Prompt Programming on Function-Level Code Generation}},
  author={Khojah, Ranim and Neto, Francisco Gomes de Oliveira and Mohamad, Mazen and Leitner, Philipp},
  journal={arXiv preprint arXiv:2412.20545},
  year={2024}
}
```

### Install dependencies
```shell
# (optional) create a virtual environment
pip install virtualenv
python -m venv .<name_of_virtual_environment>
source .<name_of_virtual_environment>/bin/activate

# install packages
pip install -r requirements.txt
```

### Contact
Please contact `khojah{at}chalmers.se` if you have any questions.
