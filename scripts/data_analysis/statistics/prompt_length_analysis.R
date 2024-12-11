
library(psych)
library(dplyr)
library(ggplot2)
library(vcd)
library(scales)  # for percent formatting
library(stringr)

model <- 'gpt3'
eval_res_path <- paste0(model, "_evaluation_codereval_v14_without_lints.csv")

raw_data <- read.csv(eval_res_path, sep = ',')

# Prompt length vs test result: Point-biserial correlation (no correlation)
prompt_df <- raw_data %>%
  filter(test_result != "") %>% 
  select(prompt_length = original_prompt_length, test_result) %>%
  mutate(prompt_length = as.numeric(prompt_length)
)

correlation_result <- biserial(prompt_df$prompt_length, prompt_df$test_result)
cat("Point-biserial correlation coefficient:", correlation_result, "\n")

if (abs(correlation_result) > 0.3) {
  cat("There is a moderate to strong correlation.\n")
} else {
  cat("There is a weak or no correlation.\n")
}

# Additional t-test to compare means across pass/fail groups
t_test_result <- t.test(prompt_df$prompt_length ~ prompt_df$test_result)
cat("T-test p-value:", t_test_result$p.value, "\n")

ggplot(prompt_df, aes(x = as.factor(test_result), y = prompt_length)) +
  geom_boxplot() +
  labs(title = "Box Plot of Prompt Length by Pass/Fail Outcome",
       x = "Pass/Fail Outcome",
       y = "Prompt Length")




# Prompt length vs similarity (no correlation)
prompt_df <- raw_data %>%
  filter(test_result == "Passed") %>% 
  select(prompt_length = original_prompt_length, similarity = codebleu) %>%
  filter(similarity != "") %>% 
  mutate(prompt_length = as.numeric(prompt_length),
         similarity = as.numeric(similarity)
  )

correlation_result <- cor.test(prompt_df$prompt_length, prompt_df$similarity, method = "pearson")
cat("Pearson correlation coefficient:", correlation_result$estimate, "\n")
cat("p-value:", correlation_result$p.value, "\n")

if (!is.na(correlation_result$estimate)) {
  if (abs(correlation_result$estimate) > 0.3) {
    cat("There is a moderate to strong correlation\n")
  } else {
    cat("There is a weak or no correlation\n")
  }
} else {
  cat("The calculation returned NA. Check data for missing values or issues.\n")
}


ggplot(prompt_df, aes(x = prompt_length, y = similarity)) +
  geom_point() +
  geom_smooth(method = "lm", col = "blue") +
  labs(title = "Scatter Plot of Prompt Length vs Code Similarity",
       x = "Prompt Length",
       y = "Code Similarity")


# Prompt length vs complexity (moderate to strong correlation)
prompt_df <- raw_data %>%
  select(prompt_length = original_prompt_length, complexity = cognitive_complexity_generated) %>%
  filter(complexity != "") %>% 
  mutate(prompt_length = as.numeric(prompt_length),
         complexity = as.numeric(complexity)
  )

correlation_result <- cor.test(prompt_df$prompt_length, prompt_df$complexity, method = "pearson")
cat("Pearson correlation coefficient:", correlation_result$estimate, "\n")
cat("p-value:", correlation_result$p.value, "\n")

if (!is.na(correlation_result$estimate)) {
  if (abs(correlation_result$estimate) > 0.3) {
    cat("There is a moderate to strong correlation\n")
  } else {
    cat("There is a weak or no correlation\n")
  }
} else {
  cat("The calculation returned NA. Check data for missing values or issues.\n")
}

ggplot(prompt_df, aes(x = prompt_length, y = complexity)) +
  geom_point() +
  geom_smooth(method = "lm", col = "blue") +
  labs(title = "Scatter Plot of Prompt Length vs Code complexity",
       x = "Prompt Length",
       y = "Code complexity")



# level vs test_results (facid grid)
models <- c('gpt4', 'llama3', 'mistral')

# Initialize an empty list to store data for each model
all_data <- list()

for (model in models) {
  eval_res_path <- paste0(model, "_evaluation_codereval_v14_with_analysis.csv")
  raw_data <- read.csv(eval_res_path, sep = ',')
  
  prompt_df <- raw_data %>%
    filter(test_result != "") %>% 
    select(level, result = test_result) %>%
    mutate(model = model)  # Add a model column for facetting
  
  summary_data <- as.data.frame(table(prompt_df$level, prompt_df$result))
  colnames(summary_data) <- c("level", "result", "Count")
  summary_data <- summary_data %>%
    group_by(level) %>%
    mutate(Percentage = Count / sum(Count)) %>%
    ungroup()
  
  summary_data$model <- model
  all_data[[model]] <- summary_data
}

combined_data <- do.call(rbind, all_data)
# Rename models for display
combined_data <- combined_data %>%
  mutate(model = case_when(
    model == "gpt4" ~ "GPT-4o",
    model == "llama3" ~ "Llama3-70B",
    model == "mistral" ~ "Mistral-22B",
    TRUE ~ model
  )) %>% 
  mutate(level = case_when(
    level == "class_runnable" ~ "Class Runnable",
    level == "file_runnable" ~ "File Runnable",
    level == "plib_runnable" ~ "Project Library Runnable",
    level == "self_contained" ~ "Self-Contained",
      level == "slib_runnable" ~ "Standard Library Runnable",
    level == "project_runnable" ~ "Project Runnable",
    TRUE ~ level
  )) %>% 
  mutate(level = str_wrap(level, width = 10))

ggplot(combined_data, aes(x = level, y = Count, fill = result)) +
  geom_bar(stat = "identity", position = "fill") +  # Stacked bars with percentages
  # Customizing the y-axis (flipped x-axis) labels to display 0 and 1 without decimal points
  scale_y_continuous(labels = function(x) ifelse(x %in% c(0, 1), as.character(x), x)) +
  geom_text(aes(label = scales::percent(Percentage, accuracy = 1)),
            position = position_fill(vjust = 0.5), size = 4.5) +  # Percentages inside bars
  labs(x = "Code levels",
       y = "Percentages of functions",
       fill = "Test Result") +
  theme_minimal() +
  scale_fill_manual(values = c("Passed" = "lightblue", "Failed" = "salmon")) +
  theme(text = element_text(size = 15)) +

  coord_flip() +  # Flip the axes
  facet_wrap(~ model)  # Grouped plot with 3 subplots for each model

#Save
vari <- "level_vs_test"
file_name <- paste0("plots/main_models_", vari, ".pdf")
ggsave(file_name, plot = last_plot(), width = 11, height = 6, dpi = 300)





# level vs test_result analysis
prompt_df <- raw_data %>%
  filter(test_result != "") %>% 
  select(level, result = test_result) 

contingency_table <- table(prompt_df$level, prompt_df$result)

cat("Contingency Table:\n")
print(contingency_table)

cramers_v <- assocstats(contingency_table)$cramer
chi_square_test <- chisq.test(contingency_table)
p_value <- chi_square_test$p.value

cat("Cramer's V:", cramers_v, "\n")
cat("p-value:", p_value, "\n")

if (p_value < 0.05) {
  cat("The relationship between code level and test result is statistically significant.\n")
} else {
  cat("The relationship between code level and test result is not statistically significant.\n")
}


# Create a summary table for counts of pass/fail by code level
summary_data <- as.data.frame(table(prompt_df$level, prompt_df$result))

colnames(summary_data) <- c("level", "result", "Count")

ggplot(summary_data, aes(x = level, y = Count, fill = result)) +
  geom_bar(stat = "identity", position = "dodge") +  # Bar positions side by side
  labs(x = "Code Level",
       y = "Number of Functions",
       fill = "Test Result") +
  theme_minimal() +
  scale_fill_manual(values = c("Passed" = "lightblue", "Failed" = "salmon")) +
  theme(text = element_text(size = 17))

#Save
vari <- "level_vs_test"
file_name <- paste0("plots/", model, "_", vari, ".pdf")
ggsave(file_name, plot = last_plot(), width = 11, height = 6, dpi = 300)



# Error types states (facid grid)
models <- c('gpt4', 'llama3', 'mistral')
all_data <- list()

for (model in models) {
  eval_res_path <- paste0(model, "_evaluation_codereval_v14_with_analysis.csv")
  raw_data <- read.csv(eval_res_path, sep = ',')
  raw_data <- raw_data %>%
    mutate(
      test_result = if_else(test_result == "", "Failed", test_result),
      error_type = if_else(test_result == "Failed" & error_type == "", "SyntaxError", error_type)
    )
  
  prompt_df <- raw_data %>%
    filter(test_result == "Failed") %>%
    select(error_type) %>%
    mutate(model = case_when(
      model == "gpt4" ~ "GPT-4o",
      model == "llama3" ~ "Llama3-70B",
      model == "mistral" ~ "Mistral-22B",
      TRUE ~ model
    ))
  
  error_counts <- prompt_df %>%
    group_by(model, error_type) %>%
    summarise(count = n()) %>%
    arrange(desc(count))
  
  all_data[[model]] <- error_counts
}

combined_data <- bind_rows(all_data)

ggplot(combined_data, aes(x = reorder(error_type, count), y = count, fill = count)) +
  geom_bar(stat = "identity") +
  labs(x = "Error Type",
       y = "Count") +
  theme_minimal() +
  theme(
    strip.text = element_text(size = 14),  # Increase facet title (strip) size
    axis.text.x = element_text(angle = 45, hjust = 1, size = 12),
    axis.text.y = element_text(size = 13),
    axis.title.x = element_text(size = 14),
    axis.title.y = element_text(size = 14),
    legend.position = "none",
    panel.spacing = unit(1, "lines")
  ) +
  scale_fill_gradient(low = "lightblue", high = "darkblue") +
  coord_flip() +
  scale_y_continuous(expand = c(0, 0), limits = c(0, 1500)) +
  facet_wrap(~ model)


#Save
vari <- "error_types"
file_name <- paste0("plots/main_models_", vari, ".pdf")
ggsave(file_name, plot = last_plot(), width = 9, height = 6, dpi = 300)






# Error types stats
prompt_df <- raw_data %>%
  filter(test_result == "Failed") %>% 
  select(error_type) 

error_counts <- prompt_df %>%
  group_by(error_type) %>%
  summarise(count = n()) %>%
  arrange(desc(count))

ggplot(error_counts, aes(x = reorder(error_type, count), y = count)) +
  geom_bar(stat = "identity", aes(fill = count)) + 
  labs(x = "Error Type", 
       y = "Count") +
  theme_minimal() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1, size=13),
    axis.title.x = element_text(size = 14), 
    axis.title.y = element_text(size = 14),
    legend.text = element_text(size = 10),
    ) +
  scale_fill_gradient(low = "lightblue", high = "darkblue", name = NULL) 


#Save
vari <- "error_types"
file_name <- paste0("plots/", model, "_", vari, ".pdf")
ggsave(file_name, plot = last_plot(), width = 9, height = 6, dpi = 300)


