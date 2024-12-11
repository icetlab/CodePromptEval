        
import re
import os
import argparse
from dotenv import load_dotenv
from model_lib import Model, NegativeTokenCountError, InsufficientAllowedTokensError, TokenError
import pandas as pd

load_dotenv()

def read_csv(file_path, delimiter=';'):
    if not os.path.exists(file_path):
        print("File not found: {}".format(file_path))
        return None
    return pd.read_csv(file_path, delimiter=delimiter)

def write_csv(df, file_path):
    df.to_csv(file_path, index=False)


def extract_code_from_response(response, task_id):
    try:
        extracted_code = re.search(r'```python(.*?)```', response, re.DOTALL).group(1).strip()
    except:
        extracted_code = None
    if extracted_code is None:
        try:
            extracted_code = re.search(r'```(.*?)```', response, re.DOTALL).group(1).strip()
        except:
            print(f"Could not extract code for task {task_id}")
            extracted_code = None
    return extracted_code


        
def main(args):
    model = args.model
    version = args.version
    language = args.language.lower()
    batch_number = args.batchnum

    dataset_filename = f"/mimer/NOBACKUP/groups/naiss2024-22-453/context_study/datasets/CoderEval/{language.capitalize()}/codereval_combination_dataset_v{version}.csv"
    data = read_csv(dataset_filename, delimiter=',') # 7072 rows
    data_to_run = data
    
    batch_dataset_map = {
    '1' : data[:1000],
    '2' : data[1000:2000],
    '3' : data[2000:3000],
    '4' : data[3000:4000],
    '5' : data[4000:5000],
    '6' : data[5000:6000],
    '7' : data[6000:]
    }
    
    if batch_number == '':
        output_file = "/mimer/NOBACKUP/groups/naiss2024-22-453/context_study/results/" + model + "/model_output/" + model + "_codereval_" + language + "_v" + str(version) + ".jsonl"
    else:
        output_file = "/mimer/NOBACKUP/groups/naiss2024-22-453/context_study/results/" + model + "/model_output/" + model + "_codereval_" + language + "_v" + str(version) + "_b" + batch_number + ".jsonl"
        data_to_run = batch_dataset_map[batch_number]
        

    # add the columns to store the generated output.
    data['generated_code'] = ""
    data["complete_response"] = ""



    # Create and store the model session in the class attribute, initializing it with the correct system prompt and temperature
    
    if model == "llama2":
        LLAMA_PATH = os.getenv("LLAMA2_PATH")
    else:
        LLAMA_PATH = "LLAMA_PATH"

    myModel: Model = Model.get(
            model_name_or_path = os.getenv(LLAMA_PATH),
            max_new_tokens= 2048,
            context_window=128000, 
            temperature=0.2)
    myModel._system_prompt = ""
    myModel._temperature = 0.2

    
    for i, item in data_to_run.iterrows():
        task_id = item['task_id']
        prompt = item['prompt']
        combination_id = item['combination_id']
        print(f"Generating code for {task_id}, with combination {combination_id}")

        response = myModel.get_response([], prompt)
        extracted_code = extract_code_from_response(response, task_id)
        
        # task_id and combination_id must match
        data.loc[(data['task_id'] == task_id) & (data['combination_id'] == combination_id), 'generated_code'] = extracted_code
        data.loc[(data['task_id'] == task_id) & (data['combination_id'] == combination_id), 'complete_response'] = response


        write_csv(data, output_file)

    print(f"Done with {i+1} tasks")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Run a model e.g., llama3 on a jsonl dataset and store outputs.')
    parser.add_argument('--version', type=str, help='Version of the trial to use')
    parser.add_argument('--language', type=str, default='python', help='Programming language to use (python, java, etc.). Make sure that it is compatible with the benchmark.')
    parser.add_argument('--model', type=str, help='LLama model to use e.g., llama3 or llama2')
    parser.add_argument('--batchnum', type=str, default='', help='number of batch to run e.g., 1, 2 (max 7)')
    args = parser.parse_args()
    main(args)
