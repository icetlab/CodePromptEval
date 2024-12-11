import importlib
import json
import ast
import textwrap
import argparse
import os
import subprocess
import sys

def read_json(filename):
    with open(filename, "r") as file:
        json_file = json.loads(file.read())
        return json_file
    
def read_jsonl(filename):
    with open(filename, "r") as file:
        return [json.loads(line) for line in file.readlines()]


def get_combinations():
    all_combinations = [
        (is_zero_shot, is_few_shot, is_chain_of_thought, is_persona, is_packages, is_signature)
        for is_zero_shot in [True, False]
        for is_few_shot in [True, False]
        for is_chain_of_thought in [True, False]
        for is_persona in [True, False]
        for is_packages in [True, False]
        for is_signature in [True, False]
    ]
    # remove the combination where zero_shot and few shot are both True or both False:
    all_combinations = [
        combination
        for combination in all_combinations
        if not (combination[0] and combination[1]) and not (not combination[0] and not combination[1])
    ]

    return all_combinations

def get_persona():
    # persona = "As an expert " + programming_language + " developer,"
    persona = "As a software developer who follows best coding practices for maintainability such as avoiding code smells and writing simple and clean code"
    return persona

def get_chain_of_thought():
    chain_of_thought = "Think carefully and logically, explaining your answer step by step."
    return chain_of_thought

def get_packages(raw_data, question_id):
    packages = []
    for row in raw_data:
        if row["_id"] == question_id:
            packages = row["all_context"]
            packages = packages.split("\"")
            packages = packages[3].strip()
            break
    return packages

def get_solution(raw_data, signature, question_id):
    for row in raw_data:
        if row["_id"] == question_id:
            complete_code = row["file_content"]
            function_name = extract_function_name(signature)
            solution = extract_function_from_code(complete_code, function_name)
            return solution



def extract_function_name(function_signature):
    function_name = function_signature.split('(')[0].split()[-1]
    return function_name


def extract_function_from_code(complete_code, function_to_extract):
    complete_code_dedented = textwrap.dedent(complete_code)
    parsed_code = ast.parse(complete_code_dedented)

    for node in ast.walk(parsed_code):
        if isinstance(node, ast.FunctionDef) and node.name == function_to_extract:
            # If the function is found, reconstruct its code
            function_code = ast.unparse(node)
            return function_code

    return None

def extract_main_block(complete_code):
    # get if __name__ == "__main__" 
    complete_code_dedented = textwrap.dedent(complete_code)
    parsed_code = ast.parse(complete_code_dedented)
    for node in ast.walk(parsed_code):
        if isinstance(node, ast.If) and isinstance(node.test, ast.Compare):
            if isinstance(node.test.left, ast.Name) and node.test.left.id == "__name__":
                if isinstance(node.test.comparators[0], ast.Constant) and node.test.comparators[0].s == "__main__":
                    main_block = ast.unparse(node)
                    return main_block
    return None

    


def get_baseline_code(raw_data, question_id):
    for row in raw_data:
            if row["_id"] == question_id:
                code = row["code"]
                return code
    return None

import sys
import importlib.util
import os
import subprocess

def is_standard_library(module_name):
    if module_name in sys.builtin_module_names:
        return True
    try:
        spec = importlib.util.find_spec(module_name)
        if spec is None or spec.origin is None:
            return False
        module_path = spec.origin

        # Get the standard library path
        std_lib_path = os.path.dirname(os.__file__)
        
        # Check if the module path is within the standard library directory
        if module_path.startswith(std_lib_path):
            return True
        
        return False
    except ImportError:
        return False
    
def check_module_needs_install(module_name):
    if module_name.replace(' ', '') == "":
        return False
    if is_standard_library(module_name):
        return False  # It's a standard library module
    try:
        print("importing ", module_name)
        importlib.import_module(module_name)
        return False  
    except ImportError:
        return True  # Module needs to be installed
    
def run_test_file(test_file):
    dependencies = set()

    with open(test_file, 'r') as f:
        lines = f.readlines()
        for line in lines:
            line = line.strip()
            if line.startswith('import ') or line.startswith('from '):
                parts = line.split()
                if parts[0] == 'import':
                    dependencies.add(parts[1].split('.')[0])
                elif parts[0] == 'from':
                    dependencies.add(parts[1].split('.')[0])

    # Filter out standard library modules
    third_party_dependencies = {dep for dep in dependencies if check_module_needs_install(dep)}

    # Install dependencies
    for dep in third_party_dependencies:
        try:
            
            subprocess.check_call(['python2.7', '-m', 'pip', 'install', dep])
        except:
            print(f"Failed to install {dep} - most probably a local package")

    subprocess.run(['python2.7', test_file])



import re
def append_prefix_to_sys_path(code):
    # Define the suffix to append
    prefix = "benchmarks/CoderEval/CoderEval"
    
    # Define a regex pattern to find sys.path.append lines
    pattern = r'(sys\.path\.append\(\s*[\'\"])(.*?)([\'\"]\s*\))'
    
    # Define a replacement function
    def replace_match(match):
        # Extract the path inside the quotes
        original_path = match.group(2)
        # Append the suffix
        new_path = f"{prefix}{original_path}"
        # Return the modified line
        return f"{match.group(1)}{new_path}{match.group(3)}"
    
    # Use re.sub with the pattern and replacement function
    modified_code = re.sub(pattern, replace_match, code)
    
    return modified_code


def generate_tests(raw_data, question_id, all_tests):
    # print("Generating tests for question_id: ", question_id)
    test_file_content = all_tests[question_id]
    for row in raw_data:
        if row["_id"] == question_id:
            test_name = row["test_name"]
            if test_name != "":
                # if the test exists, extract it
                tests = extract_function_from_code(test_file_content, test_name)
                if tests == None:
                    print("Test " , test_name, " could not be extracted question_id: ", question_id)
            else:
                # if the test does not exist, it can either be in main() or under id __name__ == "__main__"
                test_file_content = append_prefix_to_sys_path(test_file_content)
                
                if not os.path.exists("test_tests"):
                    os.makedirs("test_tests")
                
                with open("test_tests/test_" + question_id + ".py", "w") as file:
                    file.write(test_file_content)

                # run_test_file("test_tests/test_" + question_id + ".py")

                tests = extract_function_from_code(test_file_content, "main")
                if tests == None:
                    tests = extract_main_block(test_file_content)
                if tests == None:
                    print("Test in main could not be extracted question_id: ", question_id)
            return tests
    
    print("Test not found for question_id: ", question_id)
    return None
    
def extract_asserts(tests): # can be better done with AST
    lines = tests.split('\n')
    asserts = []
    for line in lines:
        if line.strip().startswith('assert'):
            asserts.append(line.strip())
    return asserts

def append_row_to_jsonl(filename, row):
    with open(filename, 'a') as file:
        file.write(json.dumps(row) + '\n') 
    

def main(args):
    version = args.version
    language = "Python"
    raw_data = read_json("benchmarks/CoderEval/CoderEval4" + language + ".json")["RECORDS"]
    labeled_data = read_jsonl("benchmarks/CoderEval/CE" + language + "HumanLabel.jsonl")
    test_file = "benchmarks/CoderEval/tests/record_testcases_map_" + language.lower() + ".json"

    all_tests_python = read_json(test_file)
    combinations = get_combinations()

    filename = "datasets/CoderEval/" + language + "/codereval_python_dataset_v" + version + "_fewshot.jsonl"
    # samples = []
    token_count = 0
    num_few_shot_examples = 2

    for combination in combinations:
            
        print("Combination: ", combination)
        num_samples = 0
        for i, row in enumerate(labeled_data):
            task_id = str(row["question_id"])
            if os.path.exists("failed_tasks.txt"):
                with open("failed_tasks.txt", "r") as f:
                    failed_tasks = f.readlines()
                    failed_tasks = [task.strip().replace('\n', '') for task in failed_tasks]

                    if task_id in failed_tasks:
                        continue

            question_id = row["question_id"]

            # get corresponding row from raw_data
            list_raw_row = [row for row in raw_data if row["_id"] == question_id]
            if len(list_raw_row) == 0:
                print("Question ID not found: ", question_id)
                continue
            raw_row = list_raw_row[0]

            # construct the prompt
            final_prompt = ""
            is_zero_shot, is_few_shot, is_chain_of_thought, is_persona, is_packages, is_signature = combination
            if is_persona:
                persona = get_persona()
                final_prompt += persona + ", "
            
            if is_chain_of_thought:
                chain_of_thought = get_chain_of_thought()
                final_prompt += chain_of_thought + "\n"

            # technically, the content of zero_shot should always be present
            zero_shot = row["docstring"]
            # zero_shot = "In " + language + ", " + row["docstring"]
            if is_zero_shot:
                final_prompt += zero_shot
            else:
                final_prompt += zero_shot

            signature = row["signature"]
            if is_signature:
                final_prompt += "The function signature is: " + signature + ". \n"

            tests = generate_tests(raw_data, question_id, all_tests_python)

            
            if is_few_shot:

                final_prompt += "Here are some examples: " 
                if "fewshot" in row.keys():
                    few_shot_extraction = "prompt"
                    few_shot = row["fewshot"]
                    final_prompt += few_shot + "\n"
                elif tests is not None and "def test_" in tests:
                    list_of_asserts = extract_asserts(tests)
                    if list_of_asserts is not None:
                        if len(list_of_asserts) >= num_few_shot_examples:
                            few_shot_extraction = str(num_few_shot_examples) + " asserts"
                            final_prompt +=  " ".join(list_of_asserts[:num_few_shot_examples]) + "\n"
                        elif len(list_of_asserts) == 1:
                            few_shot_extraction = "1 assert"
                            final_prompt += list_of_asserts[0] + "\n"
                # few_shot = generate_tests(raw_data, question_id, all_tests_python)
                
                else:
                    final_prompt += "There are no examples to provide." + "\n"
                    few_shot_extraction = "Not extracted"
                # final_prompt += "Here are some examples of expected input and output: " + "\n"
                # final_prompt += " ".join([f"{k}: {v}" for k, v in few_shot.items()]) + ". " + "\n"
            else:
                few_shot_extraction = None
            
           
            if is_packages:
                packages = get_packages(raw_data, question_id)
                if packages == "":
                    final_prompt += "The method does not use any packages." + "\n"
                else:
                    final_prompt += "The function has access (but does not necessarily use) the following packages: " + packages + ". " + "\n"

            project_name = raw_row["project"]
            class_name = raw_row["file_path"]
            solution = get_solution(raw_data, signature, question_id)


            
            # samples.append(dict(task_id=question_id, combination=combination, langugage="python", prompt=final_prompt, solution=solution, tests=""))
            # write_jsonl(filename, samples)
            constraint = "Respond with a " + language + " function in one code block."
            final_prompt = constraint + " " + final_prompt
            row_to_append = dict(task_id=question_id, combination=combination, langugage=language.lower(), prompt=final_prompt, solution=solution, tests=tests, original_prompt_length=len(zero_shot.split()), few_shot_extraction_method=few_shot_extraction, project=project_name, class_file=class_name, few_shot="")
            append_row_to_jsonl(filename, row_to_append)


            token_count += len(final_prompt.split())
            num_samples += 1
        print("Number of samples: ", num_samples)

    print(f"Total token count: {token_count}")

    # create a csv from the jsonl file

    original_dataset_filename = "benchmarks/CoderEval/CE" + language + "HumanLabel.jsonl"
    for i, row in enumerate(labeled_data):
        task_id = str(row["question_id"])
        question_id = row["question_id"]

        # get corresponding row from raw_data
        list_raw_row = [row for row in raw_data if row["_id"] == question_id]
        if len(list_raw_row) == 0:
            print("Question ID not found: ", question_id)
            continue
        raw_row = list_raw_row[0]
        row["project"] = raw_row["project"]
        row["file_path"] = raw_row["file_path"]
        # tests = generate_tests(raw_data, question_id, all_tests_python)

        if "fewshot" in row.keys():
            few_shot_extraction = "prompt"
            few_shot = row["fewshot"]
        else:
            few_shot_extraction = "Not extracted"
            few_shot = ""
        # final_prompt += "Here are some examples of expected input and output: " + "\n"
        # final_prompt += " ".join([f"{k}: {v}" for k, v in few_shot.items()]) + ". " + "\n"
        row["few_shot_extraction_method"] = few_shot_extraction
        row["few_shot"] = few_shot
        labeled_data[i] = row

    new_dataset_name = original_dataset_filename.replace(".jsonl", "_fewshot.jsonl")
    with open(new_dataset_name, 'w') as file:
        for row in labeled_data:
            file.write(json.dumps(row) + '\n')

    # create a csv from the jsonl file
    import pandas as pd
    df = pd.read_json(new_dataset_name, lines=True)
    df.to_csv(new_dataset_name.replace(".jsonl", ".csv"), index=False, sep='$')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Run the pipeline to generate a dataset, run a model e.g., gpt-4 and evaluate it.')
    parser.add_argument('--version', type=str, help='Version of the trial to use')
    args = parser.parse_args()
    main(args)