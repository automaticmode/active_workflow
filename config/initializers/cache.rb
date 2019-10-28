# Clear rails cache to avoid stale state
# (in particular cache is used to store agent types).
Rails.cache.clear
