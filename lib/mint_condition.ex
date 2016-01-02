defmodule MintCondition do
  def main(args) do
    # Hardcoded map of desired categories to mint categories:
    output_to_mint_cats = [
      {"Transportation - Bike", "Biking"},
      {"Transportation - Car - Buying", "Auto Payment"},
      {"Transportation - Car - Owning", "Gas & Fuel"},
      {"Transportation - Car - Owning", "Auto Insurance"},
      {"Transportation - Car - Owning", "Auto Other"},
      {"Transportation - Car - Owning", "Parking"},
      {"Transportation - Car - Owning", "Service & Parts"},
      {"Transportation - Public Transportation", "Public Transportation"},
      {"Transportation - Taxis & Car Rentals", "Rental Car & Taxi"},
      {"Home - Rent", "Mortgage & Rent"},
      {"Home - Utilities", "Utilities"},
      {"Home - Laundry", "Laundry"}, # Since if we owned a machine it'd be under utilities
      {"Home - Stuff/Improvements", "Furnishings"},
      {"Home - Stuff/Improvements", "Home Improvement"},
      {"Home - Stuff/Improvements", "Home Services"},
      {"Home - Stuff/Improvements", "Home Supplies"},
      {"Home - Stuff/Improvements", "Home"},
      {"Home - Stuff/Improvements", "Home Gadgets"},
      {"Home - Cell Phone", "Mobile Phone"},
      {"Home - Internet", "Internet"},      
      {"Health - Dr, Dentist, Pharmacy", "Dentist"},
      {"Health - Dr, Dentist, Pharmacy", "Doctor"},
      {"Health - Eyecare", "Eyecare"},
      {"Health - Working Out", "Gym"},
      {"Health - Working Out", "Yoga"},
      {"Health - Other", "Health & Fitness"},
      {"Health - Insurance", "Health Insurance"},
      {"Health - RSI", "Massage"},
      {"Health - Dr, Dentist, Pharmacy", "Pharmacy"},
      {"Health - PT", "Physical Therapy"},
      {"Health - RSI", "RSI Gear"},
      {"Misc - Baby Other", "Baby Supplies"},
      {"Misc - Life Insurance", "Life Insurance"},
      {"Misc - Tax Prep", "Tax Preparation"},
      {"Misc - Computer & Productivity", "Electronics & Software"}, # I put stuff like chromecast under home gadgets
      {"Misc - Clothing", "Clothing"},
      {"Misc - Personal Care", "Hair"},
      {"Misc - Personal Care", "Spa & Massage"},
      {"Misc - Personal Care", "Personal Care"},
      {"Misc - Personal Improvement", "Personal Improvement"},
      {"Misc - Ring Insurance", "Ring Insurance"},
      # {"Career - Getting a Job", "Job Hunting"},
      # {"Career - Getting a Job", "Professional License"},
      # {"Career - Startups", "Startups"},
      {"Education", "Tuition"},
      {"Education", "Education"},
      {"Food - Groceries", "Groceries"},
      {"Food - Alcohol & Bars", "Alcohol & Bars"},      
      {"Food - Eating Out", "Coffee Shops"},
      {"Food - Eating Out", "Restaurants"},
      {"Food - Eating Out", "Fast Food"},
      {"Food - Eating Out", "Snacks"},
      {"Charity", "Charity"},
      {"Charity", "Political Donation"}, # it's sort of charity, although I use this category more for selfish things
      {"Fun - Books", "Books"}, # could be education too
      {"Fun - Activities", "Activities"},
      {"Fun - Activities", "Amusement"},
      {"Fun - Activities", "Entertainment"},
      {"Fun - Movies", "Movies & DVDs"},
      {"Fun - Music", "Music"},
      {"Fun - Other Hobbies", "Hobbies"},
      {"Fun - Other Hobbies", "Minimizing"},
      {"Fun - Other Hobbies", "Sporting Goods"},
      {"Fun - Pets", "Pet Food & Supplies"},
      {"Fun - Pets", "Veterinary"},
      {"Fun - Sports", "Sports"},
      {"Fun - Video Games", "Video Games"},
      {"Fun - Gardening", "Lawn & Garden"},
      {"Gifts", "Gift"},
      {"Vacation", "Air Travel"},
      {"Vacation", "Hotel"},
      {"Vacation", "Travel"},
      {"Vacation", "Vacation"}, # from somewhere in 2015 on, i move everything from vacations here (transport, restaurants, etc)

      {"Uncategorized in Mint", "Uncategorized"},
    ]

    transaction_csv_path = Enum.at(args, 0)

    mint_condition(transaction_csv_path, output_to_mint_cats)
  end

  def mint_condition(transaction_csv_path, output_to_mint_cats) do
    {:ok, output_cats_by_mint_cats} = cat_list_to_reverse_map(output_to_mint_cats)
    {:ok, records} = read_csv(transaction_csv_path)
    records = normalize_mint_records(records)
    {:ok, recategorized_by_output_cat, unknown_by_mint_cat} = recategorize(output_cats_by_mint_cats, records)
    output_results(recategorized_by_output_cat, unknown_by_mint_cat)
  end

  def cat_list_to_reverse_map(cat_list) do
    res = %{}
    res = List.foldl(cat_list, res, fn({out_cat, mint_cat}, res) ->
      if !Map.has_key?(res, mint_cat) do
        Map.put(res, mint_cat, out_cat)
      else
        res
      end
    end)
    if length(cat_list) == Map.size(res) do
      {:ok, res}
    else
      :error
    end
  end

  def read_csv(path) do
    {:ok, str} = File.read(path)
    rows = CSVLixir.read(str)
    [headers | data_rows] = rows
    headers = Enum.map(headers, fn(h) ->
      h |> String.downcase |> String.replace(" ", "_")
    end)
    rev_records = List.foldl(data_rows, [], fn(row, rev_records) ->
      {:ok, record} = List.zip([headers, row])
      |> keyword_list_to_map
      if Map.size(record) > 0 do
        [record | rev_records]
      else
        rev_records
      end
    end)
    {:ok, Enum.reverse(rev_records)}
  end

  def keyword_list_to_map(kl) do
    err = false
    map = List.foldl(kl, %{}, fn(pair, map) ->
      {key, val} = pair
      if Map.has_key?(map, key) do
        err = true
      end
      Map.put(map, key, val)
    end)
    if err do
      :error
    else
      {:ok, map}
    end
  end

  def normalize_mint_records(records) do
    records
    |> Enum.map(fn(r) ->
      {amount, ""} = Float.parse(r["amount"])
      if r["transaction_type"] == "credit" do
        amount = -amount
      else
        "debit" = r["transaction_type"] # make sure it's debit
      end
      Map.put(r, "amount", amount)
    end)
    |> Enum.filter(fn(r) ->
      !(
        String.contains?(r["labels"], "Reimbursable") or
        r["category"] == "Credit Card Payment" or
        r["category"] == "Hide from Budgets & Trends" or
        # r["category"] == "Income" or
        (String.contains?(r["account_name"], "Health Care FSA") and r["category"] == "Income") or
        r["category"] == "Transfer for Cash Spending" or
        r["category"] == "Gift for Me" or
        r["category"] == "Taxes"
      )
    end)
  end

  def recategorize(category_map, records) do
    {recategorized, unknown_by_mint_cat} = List.foldl(records, {%{}, %{}}, fn(record, {recategorized, unknown_by_mint_cat}) ->
      out_category = if Dict.has_key?(category_map, record["category"]) do
        category_map[record["category"]]
      else
        "Unmapped"
      end
      recs_for_cat = Dict.get(recategorized, out_category, [])
      recategorized = Map.put(recategorized, out_category, [record | recs_for_cat])
 
      if out_category == "Unmapped" do
        recs_for_cat = Dict.get(unknown_by_mint_cat, record["category"], [])
        unknown_by_mint_cat = Map.put(unknown_by_mint_cat, record["category"], [record | recs_for_cat])
      end
 
      {recategorized, unknown_by_mint_cat}
    end)
    {:ok, recategorized, unknown_by_mint_cat}
  end

  def output_results(recategorized_by_output_cat, unknown_by_mint_cat) do
    cat_sums = Dict.keys(recategorized_by_output_cat)
    |> Enum.sort
    |> Enum.map(fn(out_cat) ->
      records = recategorized_by_output_cat[out_cat]
      sum = Enum.map(records, fn(r) -> r["amount"] end) |> Enum.sum()
      {out_cat, sum}
    end)

    IO.puts("Money spent in each output category:")
    Enum.each(cat_sums, fn({out_cat, sum}) ->
      :io.format("#{out_cat}: $~.2f\n", [sum])
    end)
    total = Enum.map(cat_sums, fn({cat, sum}) -> sum end) |> Enum.sum()
    :io.format("Total: $~.2f\n", [total])
    
    IO.puts("\nMoney spent in each output category (monthly average):")
    Enum.each(cat_sums, fn({out_cat, sum}) ->
      :io.format("#{out_cat}: $~.2f\n", [sum / 12])
    end)
    total = Enum.map(cat_sums, fn({cat, sum}) -> sum end) |> Enum.sum()
    :io.format("Total: $~.2f\n", [total / 12])
    
    IO.puts("\nMint categories and records that weren't mapped to an output category:")
    Enum.each(unknown_by_mint_cat, fn({cat, records}) ->
      IO.puts("#{cat}:")
      # Enum.each(records, fn(r) -> IO.puts("  #{r}") end)
      Enum.each(records, fn(r) -> IO.inspect(r) end)
    end)
    nil
  end
end
