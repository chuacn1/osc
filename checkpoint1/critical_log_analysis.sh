#!/bin/bash

# Define file paths for the log input and the script's output.
LOG_FILE="sys_log.txt"
OUTPUT_FILE="top10_critical.txt"

# Exit if the source log file does not exist.
if [ ! -f "$LOG_FILE" ]; then
    echo "Error: Log file '$LOG_FILE' not found."
    exit 1
fi

echo "Starting analysis of '$LOG_FILE'..."

#  Filter logs for critical keywords (ERROR, CRITICAL, FATAL).
# The search is case-insensitive. If no critical logs are found, the script exits.
filtered_logs=$(grep -iE "ERROR|CRITICAL|FATAL" "$LOG_FILE")

if [ -z "$filtered_logs" ]; then
    echo "No critical logs found. Exiting."
    echo "" > "$OUTPUT_FILE"
    exit 0
fi

#  Tokenize the filtered logs into individual words.
tokenized_words=$(echo "$filtered_logs" | tr '[:upper:]' '[:lower:]' | tr -c '[:alnum:]' '\n' | grep -v '^$')


# The tokenized words are sorted, counted, and then numerically sorted in descending order to find the most frequent ones. The top 10 are selected.
top_10_tokens=$(echo "$tokenized_words" | sort | uniq -c | sort -rn | head -n 10)

# Save the top 10 results to the designated output file.
echo "Analysis complete. Saving results to '$OUTPUT_FILE'."
echo "$top_10_tokens" > "$OUTPUT_FILE"

echo "Results saved to '$OUTPUT_FILE'."