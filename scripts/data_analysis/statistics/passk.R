library(dplyr)
library(tidyr)
library(ggplot2)
library(ScottKnott)

models <- c("gpt4", "llama3", "mistral")
model_titles <- c(gpt4 = "GPT-4o", llama3 = "Llama3", mistral = "Mistral")
model <- 'gpt4'

get_combination_label <- function(fewshot, cot, persona, packages, signature) {
  labels <- c()
  
  if (fewshot) labels <- c(labels, "Few-shot")
  if (cot) labels <- c(labels, "CoT")
  if (persona) labels <- c(labels, "Persona")
  if (packages) labels <- c(labels, "Pkg.")
  if (signature) labels <- c(labels, "Sig.")
  
  return(paste(labels, collapse = ", "))
}



eval_res_path <- paste0(model, "_evaluation_codereval_v14_analysis_trial.csv")
raw_data <- read.csv(eval_res_path, sep = ',')

interaction_data <- raw_data %>%
  select(test_result, error_message, is_few_shot, is_chain_of_thought, is_persona, is_packages, is_signature) 

pass_at_k_results <- interaction_data %>%
  group_by(is_few_shot, is_chain_of_thought, is_persona, is_packages, is_signature) %>%
  summarise(
    total_prompts = n(),
    passed_cases = sum(test_result == "Passed"),
    pass_at_1 = passed_cases / total_prompts
  ) %>%
  ungroup() %>%
  mutate(
    combination = interaction(
      is_few_shot, is_chain_of_thought, is_persona, is_packages, is_signature,
      sep = ", "
    )
  ) 

print(pass_at_k_results, n=32)

pass_at_k_results <- pass_at_k_results %>%
  mutate(
    combination_label = mapply(get_combination_label, is_few_shot, is_chain_of_thought, 
                               is_persona, is_packages, is_signature)
  )

pass_at_k_results <- pass_at_k_results %>%
  mutate(label_position = pass_at_1 - 0.07)  


plot <- ggplot(pass_at_k_results, aes(
  x = reorder(combination_label, pass_at_1),  
  y = pass_at_1
)) +
  geom_bar(stat = "identity", fill = "#342193") +
  coord_flip() +
  labs(
    x = NULL,
    y = "Pass@1"
  ) +
  theme_minimal() +
  theme(
  axis.text.y = element_text(size = 11, color = "black")) +
  geom_text(
    aes(y = label_position, 
        label = paste0(round(pass_at_1 * 100, 1), "%")  # Convert to percentage and round to 1 decimal place
    ),  
    color = "white",
    size = 5
  )

ggsave(paste0("plots/", model,"_pass_k_results.pdf"), plot = plot, width = 7, height = 10)
