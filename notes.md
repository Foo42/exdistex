contract supervision:

## Example use cases
* consumer
  * an FSM state entry/exit condition
    * contract is likely to be one of 2 which make up functionality, ie, functionality cannot be contained fully within the contract
    * if established contract crashes, it would ideally attempt reestablishment some amount of times before failure propegates (suggestive that the contract should be proxied by some sort of supervisor)
    * contract events need to be relayed to FSM state. Contracts should probably have ability to send messages to a given process.
      * Perhaps look at GenEvent?
      * Perhaps expose a state stream using StreamWeaver.Observable?
      * Simplest is to have contract be given pid/name of interested process.
        * It could send messages to this, on contract events.
        * messages would need some identifier, so that FSM state could identify which of its contracts fired.
        * No need to worry about subscribing again after supervisor ressurection as part of init state
        * contract could monitor its target and shutdown if it terminates (if pid? names ok?)
        * Perhaps sidestep this choice, make contract generic, and let delegate module handle message forwarding.
          * This is very similar to GenEvent approach (for better or worse)
          * In other useage scenarios such as notifications in which there is a single contract required to do work, notification logic could be fully contained in delegate module
* producer
  * a cron job
    * contract can fully contain functionality
    * Should contract ressurect if crashes?
      * pros:
        * avoid renegotiation for single transient error
      * cons
        * need to consider watching/notwatching state


* provider
  * when establishing fail should propegate to caller
  * once established shou