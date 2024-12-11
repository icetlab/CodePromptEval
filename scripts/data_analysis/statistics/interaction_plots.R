library(dplyr)
library(tidyr)
library(DoE.base)
library(FrF2)
library(ggplot2)
library(tibble)
library(gridExtra)
library(tidyverse)

models <- c("gpt4", "llama3", "mistral")
model_titles <- c(gpt4 = "GPT-4o", llama3 = "Llama3", mistral = "Mistral")

plots <- list()

for (model in models) {
  eval_res_path <- paste0(model, "_evaluation_codereval_v14_with_analysis.csv")
  
  raw_data <- read.csv(eval_res_path, sep = ',')
  
  test_result_checked <- "Passed"
  
  interaction_data <- raw_data %>% 
    mutate(
      error_message = replace_na(error_message, "SyntaxError: Invalid generated code"),
      test_result = replace_na(test_result, "Failed")
    ) %>%
    mutate(test_output = ifelse(test_result == test_result_checked, 1, 0)) %>%
    select(test_output, is_zero_shot, is_few_shot, is_chain_of_thought, is_persona, is_packages, is_signature) %>%
    mutate(
      is_few_shot = ifelse(is_few_shot == "True", 1, -1),
      is_chain_of_thought = ifelse(is_chain_of_thought == "True", 1, -1),
      is_persona = ifelse(is_persona == "True", 1, -1),
      is_packages = ifelse(is_packages == "True", 1, -1),
      is_signature = ifelse(is_signature == "True", 1, -1),
      is_zero_shot = ifelse(is_zero_shot == "True", 1, -1)
      
    ) %>%
    rename(
      Zero_shot = is_zero_shot,
      Few_shot = is_few_shot,
      CoT = is_chain_of_thought,
      Persona = is_persona,
      Packages = is_packages,
      Signature = is_signature
    )
  
  results_lm_test <- glm(test_output ~ Few_shot * Packages * Signature , data = interaction_data)
  
  coeff_data <- as.data.frame(summary(results_lm_test)$coefficients)[-1, ] %>%
    rownames_to_column(var = "Variable") %>%
    mutate(Color = case_when(
      `Pr(>|t|)` < 0.001 ~ "#003366",  # highly significant
      `Pr(>|t|)` < 0.01  ~ "#336699",  
      `Pr(>|t|)` < 0.05  ~ "#66B2FF", 
      `Pr(>|t|)` < 0.1   ~ "#99CCFF",  
      TRUE               ~ "grey"     # not significant
    ))
  
  plot <- ggplot(coeff_data, aes(x = reorder(Variable, Estimate), y = Estimate, color = Color)) +
    geom_point(size = 3) +
    geom_errorbar(aes(ymin = Estimate - `Std. Error`, ymax = Estimate + `Std. Error`), width = 0.2) +  
    theme_minimal() +
    labs(
      title = model_titles[model],  
      x = "Interaction Variables", 
      y = "Coefficient Estimate"
    ) +
    scale_color_identity() +  
    theme(
      axis.text.x = element_text(angle = 60, hjust = 1),
      plot.title = element_text(color = "darkblue", face = "bold")
    )
  
  plots[[model]] <- plot
}

grid.arrange(grobs = plots, ncol = 1)

# Save
vari <- "all_test_results_all_models"
file_name <- paste0("plots/", vari, "_regression_plot.pdf")
pdf(file_name, width = 8, height = 18)  # Set the size of the saved PDF
grid.arrange(grobs = plots, ncol = 1)    # Arrange all the plots for all error types in one column
dev.off()  # Close the PDF device





############ Error type analysis ##############
models <- c("gpt4", "llama3", "mistral")
error_types <- c("AssertionError", "AttributeError", "ImportError", "TypeError")

plots <- list()

for (error_type_checked in error_types) {
  
  model_plots <- list()
  
  for (model in models) {
    eval_res_path <- paste0(model, "_evaluation_codereval_v14_with_analysis.csv")
    raw_data <- read.csv(eval_res_path, sep = ',')
    
    interaction_data <- raw_data %>% 
      mutate(
        error_message = replace_na(error_message, "SyntaxError: Invalid generated code"),
        test_result = replace_na(test_result, "Failed")
      ) %>%
      filter(test_result == "Failed") %>%
      mutate(is_error = ifelse(error_type == error_type_checked, 1, 0)) %>%
      select(is_error, is_few_shot, is_zero_shot, is_chain_of_thought, is_persona, is_packages, is_signature) %>%
      mutate(is_few_shot = ifelse(is_few_shot == "True", 1, -1), 
             is_zero_shot = ifelse(is_zero_shot == "True", 1, -1), 
             is_chain_of_thought = ifelse(is_chain_of_thought == "True", 1, -1),
             is_persona = ifelse(is_persona == "True", 1, -1),
             is_packages = ifelse(is_packages == "True", 1, -1),
             is_signature = ifelse(is_signature == "True", 1, -1)
      ) %>%
      rename(
        Zero_shot = is_zero_shot,
        Few_shot = is_few_shot,
        CoT = is_chain_of_thought,
        Persona = is_persona,
        Packages = is_packages,
        Signature = is_signature
      )
    
    results_lm_error <- lm(is_error ~ Few_shot * CoT * Persona * Packages * Signature, data=interaction_data)
    
    coeff_data <- as.data.frame(summary(results_lm_error)$coefficients)[-1, ]
    coeff_data <- coeff_data %>%
      rownames_to_column(var = "Variable") %>%
      mutate(Color = case_when(
        `Pr(>|t|)` < 0.001 ~ "#003366",  # highly significant
        `Pr(>|t|)` < 0.01  ~ "#336699",  
        `Pr(>|t|)` < 0.05  ~ "#66B2FF", 
        `Pr(>|t|)` < 0.1   ~ "#99CCFF",  
        TRUE               ~ "grey"     # not significant
      ))
    
    plot <- ggplot(coeff_data, aes(x = reorder(Variable, Estimate), y = Estimate, color = Color)) +
      geom_point(size = 3) +
      geom_errorbar(aes(ymin = Estimate - `Std. Error`, ymax = Estimate + `Std. Error`), width = 0.2) +  
      theme_minimal() +
      labs(title = error_type_checked,  # Title includes both error type and model
           x = "Interaction Variables", 
           y = "Coefficient Estimate") +
      scale_color_identity() +  
      theme(axis.text.x = element_text(angle = 60, hjust = 1),
            plot.title = element_text(color = "darkblue", face = "bold"))
    
    model_plots[[model]] <- plot
  }
  
  plots[[error_type_checked]] <- grid.arrange(grobs = model_plots, ncol = 3)
}

grid.arrange(grobs = plots, ncol = 1)



vari <- "all_errors_all_models"
file_name <- paste0("plots/", vari, "_regression_plot.pdf")
pdf(file_name, width = 20, height = 25)  # Set the size of the saved PDF
grid.arrange(grobs = plots, ncol = 1)    # Arrange all the plots for all error types in one column
dev.off()  # Close the PDF device


##################### SIMILARITY ##################


# Summarize and add columns: count_passed, count_import, count_assertion, count_attribute ...etc.
# summary_df <- interaction_data %>% 
#   filter(test_output == test_result_checked) %>% 
#   group_by(is_fewshot, is_CoT, is_persona, is_package, is_signature) %>% 
#   tally()

models <- c("gpt4", "llama3", "mistral")
#similarity_metrics <- c("codebleu", "flow_similarity", "jaccard_similarity")
similarity_metrics <- c("jaccard_similarity")
model_titles <- c(gpt4 = "GPT-4o", llama3 = "Llama3", mistral = "Mistral")
similarity_titles <- c(codebleu = "CodeBLEU", flow_similarity = "Flow Similarity", jaccard_similarity = "Jaccard Similarity")
plots <- list()

for (model in models) {
  eval_res_path <- paste0(model, "_evaluation_codereval_v14_analysis_trial.csv")
  raw_data <- read.csv(eval_res_path, sep = ',')
  
  for (similarity_metric in similarity_metrics) {
    interaction_data <- raw_data %>%
      select(
        !!sym(similarity_metric), 
        is_signature, is_packages, is_persona, is_chain_of_thought, is_few_shot, is_zero_shot
      ) %>%
      mutate(
        is_zero_shot = ifelse(is_zero_shot == "True", 1, -1),
        is_few_shot = ifelse(is_few_shot == "True", 1, -1),
        is_chain_of_thought = ifelse(is_chain_of_thought == "True", 1, -1),
        is_persona = ifelse(is_persona == "True", 1, -1),
        is_packages = ifelse(is_packages == "True", 1, -1),
        is_signature = ifelse(is_signature == "True", 1, -1)
      ) %>%
      rename(
        Few_shot = is_few_shot,
        Zero_shot = is_zero_shot,
        CoT = is_chain_of_thought,
        Persona = is_persona,
        Packages = is_packages,
        Signature = is_signature
      )
    
    formula <- as.formula(paste0(similarity_metric, " ~ Few_shot * CoT * Persona * Packages * Signature"))
    results_lm_similarity <- lm(formula, data = interaction_data)
    
    coeff_data <- as.data.frame(summary(results_lm_similarity)$coefficients)[-1, ] %>%
      rownames_to_column(var = "Variable") %>%
      mutate(Color = case_when(
        `Pr(>|t|)` < 0.001 ~ "#003366",
        `Pr(>|t|)` < 0.01  ~ "#336699",
        `Pr(>|t|)` < 0.05  ~ "#66B2FF",
        `Pr(>|t|)` < 0.1   ~ "#99CCFF",
        TRUE               ~ "grey"
      ))
    
    plot <- ggplot(coeff_data, aes(x = reorder(Variable, Estimate), y = Estimate, color = Color)) +
      geom_point(size = 3) +
      geom_errorbar(aes(ymin = Estimate - `Std. Error`, ymax = Estimate + `Std. Error`), width = 0.2) +
      theme_minimal() +
      labs(
        title = paste(model_titles[model], "-", similarity_titles[similarity_metric]),
        x = "Interaction Variables",
        y = "Coefficient Estimate"
      ) +
      scale_color_identity() +
      theme(
        axis.text.x = element_text(angle = 60, hjust = 1),
        plot.title = element_text(color = "darkblue", face = "bold")
      )
    
    plots[[paste(model, similarity_metric, sep = "_")]] <- plot
  }
}

grid.arrange(grobs = plots, ncol = 3)





vari <- "jaccard_similarities_all_models"
file_name <- paste0("plots/", vari, "_regression_plot.pdf")
pdf(file_name, width = 20, height = 7)  # Set the size of the saved PDF
grid.arrange(grobs = plots, ncol = 3)    # Arrange all the plots for all error types in one column
dev.off()  # Close the PDF device


####################### COMPLEXITY ########################
models <- c("gpt4", "llama3", "mistral")
complexities <- c("cyclo_complexity_generated", "cognitive_complexity_generated")
complexities_titles <- c(cyclo_complexity_generated = "Cyclomatic Complexity", cognitive_complexity_generated="Cognitive Complexity")


model_titles <- c(gpt4 = "GPT-4o", llama3 = "Llama3", mistral = "Mistral")

plots <- list()

for (model in models) {
  eval_res_path <- paste0(model, "_evaluation_codereval_v14_analysis.csv")
  raw_data <- read.csv(eval_res_path, sep = ',')
  
  for (complexity in complexities) {
    # Complexity Analysis
    interaction_data <- raw_data %>%
      filter(test_result == "Passed") %>%
      select(complexity_generated = !!sym(complexity), is_signature, is_packages, is_persona, is_chain_of_thought, is_few_shot) %>%
      mutate(
        Combination = ifelse(is_few_shot == -1 & is_chain_of_thought == -1 & is_persona == -1 & is_packages == -1 & is_signature == -1, "Zero_shot", "Other"),
        is_few_shot = ifelse(is_few_shot == "True", 1, -1),
        is_chain_of_thought = ifelse(is_chain_of_thought == "True", 1, -1),
        is_persona = ifelse(is_persona == "True", 1, -1),
        is_packages = ifelse(is_packages == "True", 1, -1),
        is_signature = ifelse(is_signature == "True", 1, -1)
      ) %>%
      rename(
        Few_shot = is_few_shot,
        CoT = is_chain_of_thought,
        Persona = is_persona,
        Packages = is_packages,
        Signature = is_signature
      )
    
    results_lm_complexity <- lm(complexity_generated ~ Few_shot * CoT * Persona * Packages * Signature, data = interaction_data)
    
    coeff_data <- as.data.frame(summary(results_lm_complexity)$coefficients)[-1, ] %>%
      rownames_to_column(var = "Variable") %>%
      mutate(Color = case_when(
        `Pr(>|t|)` < 0.001 ~ "#003366",  # highly significant
        `Pr(>|t|)` < 0.01  ~ "#336699",
        `Pr(>|t|)` < 0.05  ~ "#66B2FF",
        `Pr(>|t|)` < 0.1   ~ "#99CCFF",
        TRUE               ~ "grey"     # not significant
      ))
    
    plot <- ggplot(coeff_data, aes(x = reorder(Variable, Estimate), y = Estimate, color = Color)) +
      geom_point(size = 3) +
      geom_errorbar(aes(ymin = Estimate - `Std. Error`, ymax = Estimate + `Std. Error`), width = 0.2) +
      theme_minimal() +
      labs(
        title = paste(model_titles[model], "-", complexities_titles[complexity]),  # Include model title and complexity
        x = "Interaction Variables",
        y = "Coefficient Estimate"
      ) +
      scale_color_identity() +
      theme(
        axis.text.x = element_text(angle = 60, hjust = 1),
        plot.title = element_text(color = "darkblue", face = "bold")
      )
    
    plots[[paste(model, complexity, sep = "_")]] <- plot
  }
}

grid.arrange(grobs = plots, ncol = 2)

# Save
vari <- "all_complexities_all_models"
file_name <- paste0("plots/", vari, "_regression_plot.pdf")
pdf(file_name, width = 15, height = 18)  # Set the size of the saved PDF
grid.arrange(grobs = plots, ncol = 2)    # Arrange all the plots for all error types in one column
dev.off()  # Close the PDF device

