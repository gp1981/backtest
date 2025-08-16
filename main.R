# Install and load necessary libraries

# Import required libraries ----- 
packages <- c("httr","jsonlite","tidyverse", "readxl", "lubridate","writexl",
              "ggthemes","ggplot2","openxlsx","dplyr","zoo","ggpubr","foreach", "progress",
              "plotly", "keyring")

for (package in packages) {
  if (!(package %in% installed.packages())) {
    install.packages(package)
  }
  
  # Load the package
  library(package, character.only = TRUE)
}

# Retrieve the API key ----
api_key <- keyring::key_get("API_FMP_KEY")

# Path to your input Excel file
# Make sure the file has columns named "Date" and "Ticker"
input_file_path <- "Input_Portfolio.xlsx"
output_file_path <- "Financial_Analysis_Output.xlsx"


# --- FUNCTIONS to fetch data from API ----

# Function to get historical market capitalization
get_market_cap <- function(ticker, start_date, end_date, api_key) {
  url <- paste0("https://financialmodelingprep.com/stable/historical-market-capitalization?symbol=",
                ticker,
                "&from=", start_date,
                "&to=", end_date,
                "&apikey=", api_key)
  response <- GET(url)
  if (http_type(response) == "application/json" && status_code(response) == 200) {
    content(response, "text") %>%
      fromJSON() %>%
      as_tibble()
  } else {
    warning(paste("Could not fetch market cap for", ticker, "between", start_date, "and", end_date))
    return(tibble())
  }
}

# Function to get historical dividends (from cash flow statement)
get_dividends <- function(ticker, api_key) {
  url <- paste0("https://financialmodelingprep.com/stable/cash-flow-statement?symbol=",
                ticker,
                "&period=quarter&apikey=", api_key)
  response <- GET(url)
  if (http_type(response) == "application/json" && status_code(response) == 200) {
    content(response, "text") %>%
      fromJSON() %>%
      as_tibble() %>%
      select(date, netDividendsPaid)
  } else {
    warning(paste("Could not fetch dividends for", ticker))
    return(tibble())
  }
}


# --- MAIN SCRIPT ----

# Read the input data
# The input file should have at least 'Date' and 'Ticker' columns
input_data <- read_excel(input_file_path) %>%
  mutate(Date = as.Date(Date)) # Assumes date is in a standard format like YYYY-MM-DD

# Prepare a list to store the results
results_list <- list()

# Loop through each row of the input data
for (i in 1:nrow(input_data)) {
  
  # Get the ticker and purchase date from the input file
  ticker <- input_data$Ticker[i]
  purchase_date <- input_data$Date[i]
  
  cat("Processing:", ticker, "purchased on", as.character(purchase_date), "\n")
  
  # --- Initial Market Cap Retrieval ---
  # Fetch market cap on or just after the purchase date (to handle weekends/holidays)
  initial_market_cap_data <- get_market_cap(ticker, purchase_date, purchase_date + days(7), api_key)
  
  if (nrow(initial_market_cap_data) > 0) {
    initial_mkt_cap <- initial_market_cap_data %>%
      arrange(date) %>% # Sort by date to get the earliest record
      slice(1) %>%      # Take the first available day's market cap
      pull(marketCap)
  } else {
    warning(paste("Could not find initial market cap for", ticker, ". Skipping."))
    next # Skip to the next ticker if we can't get the initial value
  }
  
  # --- Future Market Cap Processing ---
  
  # Define the 5-year period for which to fetch future data
  start_date <- purchase_date
  end_date <- purchase_date + years(5)

  # Fetch the market cap data for the entire 5-year period at once
  market_cap_data <- get_market_cap(ticker, start_date, end_date, api_key)
  
  if (nrow(market_cap_data) > 0) {
    market_cap_data <- market_cap_data %>%
      mutate(date = as.Date(date))
    
    # Calculate the market cap at 12, 24, 36, 48, 60 months
    mkt_cap_periods <- map_dbl(c(12, 24, 36, 48, 60), function(months) {
      target_date <- purchase_date %m+% months(months)
      # Find the first available market cap on or after the target date
      future_market_cap <- market_cap_data %>%
        filter(date >= target_date) %>%
        arrange(date) %>%
        slice(1) %>%
        pull(marketCap)
      # If no data is found for the future date, return NA
      if (length(future_market_cap) == 0) NA else future_market_cap
    })
  } else {
    mkt_cap_periods <- rep(NA, 5)
  }
  
  # --- Dividend Processing ---
  
  # Fetch all quarterly dividend data for the ticker
  dividend_data <- get_dividends(ticker, api_key)

  if (nrow(dividend_data) > 0) {
    dividend_data <- dividend_data %>%
      mutate(date = as.Date(date))
    
    # Calculate the sum of dividends for each 12-month period
    dividend_periods_annual <- map_dbl(0:4, function(year_offset) {
      period_start_date <- purchase_date %m+% months(12 * year_offset)
      period_end_date <- purchase_date %m+% months(12 * (year_offset + 1))
      
      dividend_sum <- dividend_data %>%
        filter(date > period_start_date & date <= period_end_date) %>%
        summarise(total_dividends = sum(netDividendsPaid, na.rm = TRUE)) %>%
        pull(total_dividends)
      
      # The API returns negative values for dividends paid out
      # We make them positive for our calculation
      abs(dividend_sum)
    })
  } else {
    dividend_periods_annual <- rep(NA, 5)
  }

  # --- Total Return & CAGR Calculation ---
  
  # Calculate cumulative dividends for total return calculation
  dividend_periods_cumulative <- cumsum(dividend_periods_annual)
  
  # Calculate Total Return on Investment for each period using cumulative dividends
  # Formula: (Ending Market Cap + Cumulative Dividends) / Initial Market Cap
  total_return_periods <- (mkt_cap_periods + dividend_periods_cumulative) / initial_mkt_cap
  
  # Calculate CAGR for each period
  # Formula: (Total Return)^(1 / Number of Years) - 1
  cagr_periods <- c(
    (total_return_periods[1])^(1/1) - 1,
    (total_return_periods[2])^(1/2) - 1,
    (total_return_periods[3])^(1/3) - 1,
    (total_return_periods[4])^(1/4) - 1,
    (total_return_periods[5])^(1/5) - 1
  )
  
  # --- Store the results ---
  
  # Create a tibble of the new results
  new_data <- tibble(
    `Initial MktCap` = initial_mkt_cap,
    `MktCap after 12M` = mkt_cap_periods[1],
    `MktCap after 24M` = mkt_cap_periods[2],
    `MktCap after 36M` = mkt_cap_periods[3],
    `MktCap after 48M` = mkt_cap_periods[4],
    `MktCap after 60M` = mkt_cap_periods[5],
    `Dividends 0-12M` = dividend_periods_annual[1],
    `Dividends 12-24M` = dividend_periods_annual[2],
    `Dividends 24-36M` = dividend_periods_annual[3],
    `Dividends 36-48M` = dividend_periods_annual[4],
    `Dividends 48-60M` = dividend_periods_annual[5],
    `Total Return 12M` = total_return_periods[1],
    `Total Return 24M` = total_return_periods[2],
    `Total Return 36M` = total_return_periods[3],
    `Total Return 48M` = total_return_periods[4],
    `Total Return 60M` = total_return_periods[5],
    `CAGR 12M` = cagr_periods[1],
    `CAGR 24M` = cagr_periods[2],
    `CAGR 36M` = cagr_periods[3],
    `CAGR 48M` = cagr_periods[4],
    `CAGR 60M` = cagr_periods[5]
  )
  
  # Combine the original data from that row with the new data
  results_list[[i]] <- bind_cols(input_data[i, ], new_data)
}

# Combine all results into a single data frame
final_results <- bind_rows(results_list)

# --- FORMATTING AND EXPORT ---

# Format the market cap and dividend columns to be in millions
# and format the CAGR columns as percentages
final_results_formatted <- final_results %>%
  mutate(across(contains("MktCap") | contains("Dividend"), ~ . / 1000000))

# Export the final data frame to an Excel file
write_xlsx(final_results_formatted, output_file_path)

cat("\nProcessing complete! Output saved to:", output_file_path, "\n")