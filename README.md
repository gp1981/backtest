# Financial Fundamentals & Total Return Analyzer

This R script automates the process of fetching historical financial data for a list of stock tickers from the [FinancialModelingPrep API](https://financialmodelingprep.com/developer/docs/). Given an input file with tickers and purchase dates, it calculates and retrieves the market capitalization and dividends paid over subsequent 12, 24, 36, 48, and 60-month periods. It then calculates the Total Return on Investment for each of these periods and exports the results into a formatted Excel spreadsheet.

## Features

  - **Automated Data Retrieval**: Fetches historical market capitalization and dividend data directly from the FinancialModelingPrep API.
  - **Time-based Analysis**: Calculates financial metrics at 12, 24, 36, 48, and 60 months post-purchase date.
  - **Total Return Calculation**: Computes the Total Return on Investment (TRI) for each period, combining market cap appreciation and dividends.
  - **Batch Processing**: Processes a list of tickers from an input CSV file.
  - **Formatted Excel Output**: Generates a clean, human-readable Excel file with results, formatting large numbers into millions for clarity.
  - **Efficient API Usage**: Minimizes API calls by downloading a 5-year data chunk for each ticker and post-processing it locally.

## Requirements

To run this script, you will need:

  - R (version 4.0 or higher recommended)
  - RStudio (recommended for an easier user experience)
  - A free or paid API key from [FinancialModelingPrep](https://www.google.com/search?q=https://financialmodelingprep.com/register)

## Installation

1.  **Clone the repository or download the script.**

2.  **Install the required R packages.** Open your R or RStudio console and run the following command:

    ```r
    install.packages(c("tidyverse", "httr", "jsonlite", "lubridate", "readxl", "writexl"))
    ```

## Usage

1.  **Set Your API Key**:

      - Open the R script.
      - Find the line: `api_key <- "xxx"`
      - Replace `"xxx"` with your actual API key from FinancialModelingPrep.

2.  **Prepare Your Input File**:

      - Create a CSV file (e.g., `input_data.csv`).
      - This file **must** contain the following columns with exact names:
          - `Date`: The date of the stock purchase in `YYYY-MM-DD` format.
          - `Ticker`: The stock ticker symbol (e.g., `AAPL`, `GOOGL`).
      - Place this file in the same directory as the R script.

3.  **Configure File Paths**:

      - In the script, update the `input_file_path` variable to match the name of your input file.
      - (Optional) Change the `output_file_path` if you want a different name for the output Excel file.

    <!-- end list -->

    ```r
    # --- CONFIGURATION ---
    input_file_path <- "your_input_file.csv"
    output_file_path <- "Financial_Analysis_Output.xlsx"
    ```

4.  **Run the Script**:

      - Execute the entire R script.
      - The script will print the progress for each ticker being processed in the console.
      - Once completed, a new Excel file (e.g., `Financial_Analysis_Output.xlsx`) will be created in the same directory with the results.

## Input File Format (`.csv`)

Your input CSV file should look like this:

| Date       | Ticker |
| :--------- | :----- |
| 2020-04-25 | SUPN   |
| 2020-04-25 | PRDO   |
| 2019-01-15 | AAPL   |

## Output File Format (`.xlsx`)

The output Excel file will contain the original input data plus the following calculated columns:

  - **MktCap after 12M/24M/.../60M**: Market capitalization at each period after the purchase date (in millions).
  - **Dividend after 12M/24M/.../60M**: Sum of dividends paid during each 12-month period (in millions).
  - **Total Return Investment 12M/24M/.../60M**: The total return for each period, calculated as `(Ending Market Cap + Dividends) / Initial Market Cap`.

## Disclaimer

This script is intended for educational and informational purposes only. The data is provided by FinancialModelingPrep and may not be 100% accurate. This is not financial advice. Please perform your own due diligence before making any investment decisions.

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.
