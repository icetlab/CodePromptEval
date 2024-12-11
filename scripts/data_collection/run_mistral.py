import json      
import re
import os
import argparse
from dotenv import load_dotenv
from model_lib import Model, NegativeTokenCountError, InsufficientAllowedTokensError, TokenError

load_dotenv()

def read_jsonl(filename):
    with open(filename, "r") as file:
        return [json.loads(line) for line in file.readlines()]

def append_row_to_jsonl(filename, row):
    with open(filename, 'a') as file:
        file.write(json.dumps(row) + '\n') 
        
        
def main(args):
    model = "mistral"
    version = args.version
    language = args.language.lower()
    subset = args.subset
    batch_number = args.batchnum

    numeric_version = version

    original_data = "/mimer/NOBACKUP/groups/naiss2024-22-453/context_study/datasets/CoderEval/" + language.capitalize() + "/codereval_" + language + "_dataset_v" + numeric_version + ".jsonl"
    dataset_filename = original_data
    data = read_jsonl(dataset_filename)
    
    batch_dataset_map = {
    '1' : data[:1000],
    '2' : data[1000:2000],
    '3' : data[2000:3000],
    '4' : data[3000:4000],
    '5' : data[4000:5000],
    '6' : data[5000:6000],
    '7' : data[6000:]
    }
    
    data_to_run = data
    
    if batch_number == '':
        output_file = "/mimer/NOBACKUP/groups/naiss2024-22-453/context_study/results/" + model + "/model_output/" + model + "_codereval_" + language + "_v" + str(version) + ".jsonl"
    else:
        output_file = "/mimer/NOBACKUP/groups/naiss2024-22-453/context_study/results/" + model + "/model_output/" + model + "_codereval_" + language + "_v" + str(version) + "_b" + batch_number + ".jsonl"
        data_to_run = batch_dataset_map[batch_number]
        
    

    # Create and store the model session in the class attribute, initializing it with the correct system prompt and temperature
    myModel: Model = Model.get(
            model_name_or_path = os.getenv("MISTRAL_PATH"),
            max_new_tokens= 2048,
            context_window=128000, 
            temperature=0.2)
    myModel._system_prompt = ""
    myModel._temperature = 0.2

    
    for item in data_to_run:
        prompt = re.sub(r'\n', '', item['prompt'])

        response = myModel.get_response([], prompt)

        try:
            extracted_code = re.search(r'```python(.*?)```', response, re.DOTALL).group(1).strip()
        except:
            print("Code could not be extracted")
            extracted_code = None

      
        
        row_to_append = {"task_id" : item["task_id"], "combination": item["combination"], "prompt" : prompt, "generated_code" : extracted_code, "groundtruth_code" : item["solution"], "complete_response" : response, "tests" : item["tests"], "programming_language" : language, "total_tokens" : "N/A"}
        append_row_to_jsonl(output_file, row_to_append)
        

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Run a model e.g., gpt-4 on a jsonl dataset and store outputs.')
    parser.add_argument('--version', type=str, help='Version of the trial to use')
    parser.add_argument('--language', type=str, default='python', help='Programming language to use (python, java, etc.). Make sure that it is compatible with the benchmark.')
    parser.add_argument('--subset', type=int, default=0, help='Size of the subset of tasks in the dataset to use')
    parser.add_argument('--batchnum', type=str, default='', help='number of batch to run e.g., 1, 2 (max 7)')
    args = parser.parse_args()
    main(args)
