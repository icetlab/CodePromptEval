
library(dplyr)
library(effsize) # For computing Vargha-Delaney A measure

model <- 'llama3'
eval_res_path <- paste0(model, "_evaluation_codereval_v14_analysis.csv")
result_file <- paste0("results/cogn_complexity", "_wilcox_", model, ".txt")

raw_data <- read.csv(eval_res_path, sep = ',')

# select the columns I need
complexity_df <- raw_data %>%
  mutate(
    error_message = replace_na(error_message, "SyntaxError: Invalid generated code"),
    test_result = replace_na(test_result, "Failed")
  ) %>%
  filter(test_result == "Passed")  %>%
  select("combination" = prompt_techniques_applied, "complexity_generated" = cognitive_complexity_generated, "complexity_groundtruth" = cognitive_complexity_groundtruth, test_result) %>% 
  mutate(complexity_generated = as.numeric(complexity_generated), 
         complexity_groundtruth = as.numeric(complexity_groundtruth))


unique_combinations <- unique(complexity_df$combination)

for (current_combination in unique_combinations) {
  combination_df <- complexity_df %>% 
    filter(combination == current_combination, test_result == "Passed")
  
  complexity_generated = combination_df$complexity_generated 
  complexity_groundtruth = combination_df$complexity_groundtruth
  
  res <- wilcox.test(complexity_generated, complexity_groundtruth, paired=TRUE)
  
  
  # Vargha-Delaney A12 measure
  a12 <- VD.A(complexity_generated, complexity_groundtruth)$estimate
  
  if (res$p.value <= 0.05) {
    hypothesis <- "difference"
    if (a12 > 0.4) {
      effect <- "Generated more complex"
    } else if (a12 < 0.4) {
      effect <- "Generated less complex"
    } else {
      effect <- "No effect"
    }
  } else {
    hypothesis <- "no difference"
    effect <- "No effect"
  }
  
  stat_results <- paste("Combination:", current_combination,
                        "| Hypothesis:", hypothesis,
                        "| p-value:", res$p.value,
                        "| A12:", round(a12, 3),
                        "| Effect:", effect)
  print(stat_results)
  
  cat(stat_results, file = result_file, append = TRUE, sep = "\n")
  
  
}



