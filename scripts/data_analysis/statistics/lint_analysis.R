library(dplyr)
library(tidyr)
library(ggplot2)
library(RColorBrewer)

models <- c("gpt4", "llama3", "mistral")
model_titles <- c(gpt4 = "GPT-4o", llama3 = "Llama3", mistral = "Mistral")

model <- "gpt4"

eval_res_path <- paste0(model, "_evaluation_codereval_v14_combination_lint_analysis.csv")

data_df <- read.csv(eval_res_path, sep = ',')

####################### LINT TYPES AND FREQUENCIES #########################

parse_lint_types <- function(lint_str) {
  lint_str <- gsub("\\[|\\]", "", lint_str) # Remove brackets
  tuples <- strsplit(lint_str, "\\), \\(")[[1]] # Split into tuples
  
  # Process each tuple to extract lint type and frequency
  lint_data <- lapply(tuples, function(t) {
    t <- gsub("[()']", "", t) 
    parts <- strsplit(t, ", ")[[1]] 
    list(lint_type = parts[1], frequency = as.numeric(parts[2]))
  })
  
  lint_df <- do.call(rbind, lapply(lint_data, as.data.frame))
  return(lint_df)
}

parsed_data <- data_df %>%
  rowwise() %>%
  mutate(lint_types_parsed = list(parse_lint_types(lint_types))) %>%
  unnest(lint_types_parsed) %>%
  select(combination_id, lint_type, frequency)

total_frequencies <- parsed_data %>%
  group_by(combination_id) %>%
  summarise(
    total_frequency = sum(frequency),
    total_count = n()
  )


autumn_palette_13 <- c(
  "#FF6F00", "#8B4513", "#FF8F00", "#FF6347", "#B22222",
           "#FF4500", "#FFCC00", "#D2691E", "#A52A2A", "#FFB300", "#800000",
           "#FFD700", "#FF4660"
)

plot <- ggplot(parsed_data, aes(x = lint_type, y = frequency, fill = lint_type)) +
  geom_bar(stat = "identity") +
  geom_text(aes(label = frequency), vjust = -0.5, size = 5) + 
  scale_y_continuous(limits = c(0, 140)) + 
  facet_wrap(~combination_id, scales = "fixed", ncol = 4) +
  scale_fill_manual(values = autumn_palette_13) + 
  labs(
    x = "Lint (Code Smell) Code",
    y = "Frequency"
  ) + 
  theme_minimal() +
  facet_wrap(~combination_id, scales = "fixed", ncol = 4, 
             labeller = labeller(combination_id = function(x) {
               total_sum <- total_frequencies$total_frequency[total_frequencies$combination_id == x]
               total_count <- total_frequencies$total_count[total_frequencies$combination_id == x]
               paste0(x, " (Total: ", total_sum, " - in ", total_count, " functions)")
             })) +
  theme(
    strip.text = element_text(size = 12, color = "black"),
    axis.text.x = element_text(angle = 45, hjust = 1, size = 12, color = "black"),
    legend.position = "none",
    axis.title.x = element_text(size = 16, margin = margin(t = 10)), 
    axis.title.y = element_text(size = 16, margin = margin(r = 10))
  )

ggsave(paste0("plots/", model, "_lint_types_plot.pdf"), plot = plot, width = 23, height = 20)


######## heatmap
library(tidyr)
library(ggplot2)
library(dplyr)

model <- "llama3"

eval_res_path <- paste0(model, "_evaluation_codereval_v14_combination_lint_analysis.csv")

# Read and parse data
data_df <- read.csv(eval_res_path, sep = ',')

parse_lint_types <- function(lint_str) {
  lint_str <- gsub("\\[|\\]", "", lint_str)
  tuples <- strsplit(lint_str, "\\), \\(")[[1]]
  lint_data <- lapply(tuples, function(t) {
    t <- gsub("[()']", "", t)
    parts <- strsplit(t, ", ")[[1]]
    list(lint_type = parts[1], frequency = as.numeric(parts[2]))
  })
  do.call(rbind, lapply(lint_data, as.data.frame))
}

parsed_data <- data_df %>%
  rowwise() %>%
  mutate(lint_types_parsed = list(parse_lint_types(lint_types))) %>%
  unnest(lint_types_parsed) %>%
  select(combination_id, lint_type, frequency) %>% 
  filter(lint_type != "C0304")  %>% 
  mutate(
    combination_id = gsub("Chain-of-Thought", "CoT", combination_id),
    combination_id = gsub("Signature", "Sig.", combination_id),
    combination_id = gsub("Packages", "Pkg.", combination_id),
    )


# Order columns by total frequency
total_frequency_per_lint <- parsed_data %>%
  group_by(lint_type) %>%
  summarise(total_frequency = sum(frequency), .groups = 'drop') %>%
  arrange(desc(total_frequency))

ordered_lint_types <- total_frequency_per_lint$lint_type

# Reorder columns in the heatmap_data
heatmap_data <- parsed_data %>%
  pivot_wider(names_from = lint_type, values_from = frequency, values_fill = 0)

# Ensure the columns are ordered based on total_frequency_per_lint
heatmap_data <- heatmap_data %>%
  select(combination_id, all_of(ordered_lint_types))

# Calculate total frequency per combination and sort combinations
total_frequency_per_combination <- parsed_data %>%
  group_by(combination_id) %>%
  summarise(total_combination_frequency = sum(frequency), .groups = 'drop') %>%
  arrange(desc(total_combination_frequency))

# Reorder heatmap_data based on this sorting
heatmap_data <- heatmap_data %>%
  left_join(total_frequency_per_combination, by = "combination_id") %>%
  arrange(desc(total_combination_frequency)) %>%
  select(-total_combination_frequency)  # Remove the temporary sorting column

# Set combination_id as a factor with levels in the desired order
heatmap_data_long <- heatmap_data %>%
  pivot_longer(cols = -combination_id, names_to = "lint_type", values_to = "frequency") %>%
  mutate(
    combination_id = factor(combination_id, levels = total_frequency_per_combination$combination_id),
    lint_type = factor(lint_type, levels = ordered_lint_types)
  )

# Plot
plot <- ggplot(heatmap_data_long, aes(x = lint_type, y = combination_id, fill = frequency)) +
  geom_tile(color = "white", size = 0.1) +
  geom_text(data = subset(heatmap_data_long, frequency > 0), aes(label = frequency), color = "white", size = 4) +
  scale_fill_gradient(low = "lightblue", high = "darkblue", name = "Frequency") +
  labs(
    x = "Code Smell (Lint ID)",
    y = NULL,
  ) +
  theme_minimal() +
  theme(
    axis.title.x = element_text(color="black", size=14, margin = margin(t = 13)),
    axis.text.x = element_text(angle = 45, hjust = 1, size = 12, color = "black"),
    axis.text.y = element_text(size = 12, color = "black"),
    legend.position = "none"
  )

# Save plot
if (!dir.exists("plots")) dir.create("plots")
ggsave(paste0("plots/", model, "_lint_types_heatmap.pdf"), plot = plot, width = 8, height = 10)


####################### LINT SCORE #########################


ggplot(data_df, aes(x = factor(combination_id), y = avg_lint_score)) +
  geom_bar(stat = "identity", fill = "skyblue", color = "black", width = 0.6) +
  geom_errorbar(
    aes(ymin = avg_lint_score - std_dev_lint_score, ymax = avg_lint_score + std_dev_lint_score),
    width = 0.2,
    color = "red"
  ) +
  labs(
    title = "Average Lint Scores with Standard Deviation",
    x = "Combination ID",
    y = "Average Lint Score"
  ) +
  theme_minimal()

