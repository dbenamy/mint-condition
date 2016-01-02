# MintCondition

This is a little tool that maps mint.com transaction records to categories that I prefer, and does a bit more filtering that's useful for how I track my spending. I also used it to learn a bit of elixir.

It's probably not terribly useful to others, but it can't hurt to share just in case someone else does a similar thing.


# Usage

Don't forget to add rent, medical insurance, accountant, and anything else that's not paid by credit card, to mint.

Go to https://wwws.mint.com/transaction.event?exclHidden=T&startDate=1/1/2015&endDate=01/01/2016&accountId=0&query=-category:Credit+Card+Payment, download all transactions, and run `mix deps.get && mix escriptize && ./mint_condition transactions.csv`.

Results may not exactly match mint since their transaction export doesn't exactly match what's shown. Eg 1 difference I've found is that duplicates are shown with category duplicate, but the exported csv will show their original category.
