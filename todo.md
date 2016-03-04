* Separate out provider which listens for requests and starts provider contracts to complete negotiation
* Pass existing connection into contracts
* consider supervision, is it our responsibility, or calling code? Do we make it easy enough to supervise contracts? Consider supervising contract proxies which manage renegotiation.