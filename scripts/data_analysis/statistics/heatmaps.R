library(tidyverse)
library(ggplot2)

models <- c("gpt4", "llama3", "mistral")
similarity_metrics <- c("codebleu", "ngram_similarity", "weighted_ngram_similarity", "syntax_similarity")

similarity_metrics <- c("codebleu")
similarity_titles <- c(codebleu = "CodeBLEU", flow_similarity = "Semantic Similarity (Dataflow)", jaccard_similarity = "Jaccard Similarity", syntax_similarity = "Syntactic Similarity (AST) - 33.33%", ngram_similarity= "BLEU (n-gram) - 33.33%", weighted_ngram_similarity="BLEU-weighted - 33.33%")

models_titles <- c("gpt4" = "GPT-4o", "llama3" = "Llama3", "mistral" = "Mistral")
significance_colors <- c(
  "<0.001" = "#336699",
  "<0.01"  = "#66B2FF",
  "<0.05"  = "#99CCFF",
  "Not Significant" = "grey"
)


all_coeff_data <- list()

for (model in models) {
  eval_res_path <- paste0(model, "_evaluation_codereval_v14_analysis_trial3.csv")
  raw_data <- read.csv(eval_res_path, sep = ',')
  
  for (similarity_metric in similarity_metrics) {
    interaction_data <- raw_data %>%
      mutate(
        error_message = replace_na(error_message, "SyntaxError: Invalid generated code"),
        test_result = replace_na(test_result, "Failed")
      ) %>%
      select(
        !!sym(similarity_metric),
        test_result,
        is_signature, is_packages, is_persona, is_chain_of_thought, is_few_shot, is_zero_shot
      ) %>%
      mutate(test_result = ifelse(test_result == "Passed", 1, 0)) %>%
      mutate(
        is_zero_shot = ifelse(is_zero_shot == "True", 1, -1),
        is_few_shot = ifelse(is_few_shot == "True", 1, -1),
        is_chain_of_thought = ifelse(is_chain_of_thought == "True", 1, -1),
        is_persona = ifelse(is_persona == "True", 1, -1),
        is_packages = ifelse(is_packages == "True", 1, -1),
        is_signature = ifelse(is_signature == "True", 1, -1)
      ) %>%
      rename(
        "Fewshot" = is_few_shot,
        "Zero_shot" = is_zero_shot,
        "CoT" = is_chain_of_thought,
        "Persona" = is_persona,
        "Pkg." = is_packages,
        "Sig." = is_signature
      )
    
    # Linear model fitting
    formula <- as.formula(paste0(similarity_metric, " ~ Fewshot * CoT * Persona * Pkg. * Sig."))
    results_lm_similarity <- glm(formula, data = interaction_data)
    
    coeff_data <- as.data.frame(summary(results_lm_similarity)$coefficients)[-1, ] %>%
      rownames_to_column(var = "Variable") %>%
      mutate(
        Model = models_titles[model],
        Metric = similarity_metric,
        Significance = case_when(
          `Pr(>|t|)` < 0.001 ~ "<0.001",
          `Pr(>|t|)` < 0.01  ~ "<0.01",
          `Pr(>|t|)` < 0.05  ~ "<0.05",
          TRUE               ~ "Not Significant"
        )
      ) %>%
      select(Variable, Estimate, Model, Metric, Significance)
    
    # Add to the list for all data
    all_coeff_data[[paste0(model, "_", similarity_metric)]] <- coeff_data
  }
}

# Combine all coefficient data
combined_coeff_data <- bind_rows(all_coeff_data)
combined_coeff_data <- combined_coeff_data %>%
  mutate(
    Significance = factor(Significance, levels = c("<0.001", "<0.01", "<0.05", "Not Significant"))
  ) 

heatmap_data <- combined_coeff_data %>%
  mutate(Coefficient = as.numeric(Estimate))  # Ensure numeric coefficients

# Order rows by the highest coefficient value
heatmap_data <- heatmap_data %>%
  group_by(Variable) %>%
  summarize(MaxCoefficient = max(Coefficient, na.rm = TRUE)) %>%
  arrange(desc(MaxCoefficient)) %>%
  inner_join(heatmap_data, by = "Variable") %>%
  mutate(Variable = reorder(Variable, MaxCoefficient))

print(levels(heatmap_data$Significance))  # Ensure these are correct

plot <- ggplot(heatmap_data, aes(x = Coefficient, y = Variable, shape = Model, fill = Significance)) +  
  geom_point(size = 4) +  # Use fixed size for all points
  scale_shape_manual(values = c(21, 22, 23)) + 
  scale_fill_manual(
    values = significance_colors  
  ) + 
  labs(
    title = "CodeBLEU",
    x = "Coefficient Estimate",
    y = NULL,
    fill = "Significance Level",  # Label for the color legend
    shape = "LLM"  # Label for the shape legend
  ) + 
  theme_minimal() + 
  theme(
    plot.title = element_text(margin = margin(b = 12, r = 0, t = 0, l = 0), color = "black"),
    axis.title.x = element_text(margin = margin(t = 12, r = 0, b = 0, l = 0), color = "black"),
    axis.title.y = element_text(margin = margin(t = 0, r = 5, b = 0, l = 0), color = "black"),
    axis.text.y = element_text(size = 13, color = "black"),
    axis.text.x = element_text(size = 10, color = "black"),
    panel.grid.major.x = element_line(color = "grey80"),
    panel.grid.minor.x = element_blank(),
    legend.box = "vertical",  # Arrange legend items horizontally
    legend.position = "bottom",  # Move legend below the plot
    legend.title = element_text(size = 12),  # Adjust legend title size
    legend.text = element_text(size = 10)  # Adjust legend text size
  ) +
  guides(
    fill = guide_legend(override.aes = list(color = significance_colors)) 
  )




vari <- "CodeBLEU_all_models"
ggsave(paste0("plots/", vari, ".pdf"), plot = plot, width = 8, height = 9)



###################


# Combine all coefficient data
combined_coeff_data <- bind_rows(all_coeff_data)

# Ensure 'Significance' is a factor with the correct levels
combined_coeff_data <- combined_coeff_data %>%
  mutate(
    Significance = factor(Significance, levels = c("<0.001", "<0.01", "<0.05", "Not Significant")),
    Metric = factor(Metric, levels = similarity_metrics)
  )

selected_variables <- c("Fewshot", "Sig.", "Pkg." , "Fewshot:Sig.", "Persona", "Fewshot:CoT","Fewshot:CoT:Persona", "CoT", "CoT:Persona")

# Filter the data for selected combinations
combined_coeff_data <- combined_coeff_data %>%
  filter(Variable %in% selected_variables)

# Calculate summary statistic (mean or max of Estimate) to reorder variables
combined_coeff_data <- combined_coeff_data %>%
  group_by(Variable) %>%
  summarize(MeanEstimate = mean(Estimate, na.rm = TRUE)) %>%  # Change to max if preferred
  inner_join(combined_coeff_data, by = "Variable") %>%
  mutate(Variable = reorder(Variable, MeanEstimate))  # Reorder based on MeanEstimate


# Create the plot with faceting
plot <- ggplot(combined_coeff_data, aes(x = Estimate, y = Variable, shape = Model, fill = Significance)) +
  geom_point(size = 4, position = position_dodge(width = 0.5)) +  # Dodge points for better separation
  scale_shape_manual(values = c(21, 22, 23)) +  # Distinct shapes for models
  scale_fill_manual(values = significance_colors) +  # Custom significance colors
  labs(
    x = "Coefficient Estimate",
    y = NULL,
    fill = "Significance Level",  # Label for the fill legend
    shape = "LLM"  # Label for the shape legend
  ) +
  facet_grid(. ~ Metric, scales = "free_y", labeller = labeller(Metric = similarity_titles)) +  # Place all facets in one row
  theme_minimal() +
  theme(
    strip.background = element_rect(fill = "grey90", color = "black", size = 0.5),
    strip.text = element_text(size = 12, face = "bold"),
    legend.box = "horizontal",  # Arrange legend items horizontally
    legend.position = "bottom",  # Move legend below the plot
    axis.title.x = element_text(margin = margin(t = 12)),
    panel.spacing = unit(2.2, "lines")  # Add vertical spacing
  ) +
  guides(
    fill = guide_legend(override.aes = list(color = significance_colors))  # Ensure the legend matches the colors
  )


vari <- "simil_all_models"
ggsave(paste0("plots/", vari, ".pdf"), plot = plot, width = 20, height = 5)

