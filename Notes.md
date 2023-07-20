Events
    events are used to communicate with client application or front-end applications

    event name(
        uint256 indexed indexed_param1;
        uint256 number;
    )

    + Upto 3 Index parameters can be used in events, 
    + Indexed parameters(topics) are searchable
    
    emit name(parameters);

Chainlink VRF

    chainlink service to get a random number
    + Use sepolia testnet eth to get the subscription to chainlink VRF;
    +

+We can install  smartcontractkit/chainlink repo to get the VRFCoordinatorV2Interface which is used to interact with the coordinator.
+  smartcontractkit/chainlink-brownie-contracts is minimal repo so can install from it
    forge install smartcontractkit/chainlink-brownie-contracts@0.6.1 --no-commit


// CHECKS EFFECTS INTERACTIONS



## CHAINLINK AUTOMATION





+ forge coverage --report // to get uncovered lines


+ forge test --fork-url $SPELIA_RPC_URL 
    (failing)
    - because of the addConsumer, 
        - we are using wrong private key.
        + So, we have to Pass the private key to vm.startBroadcast
        + We have to pretended to be owner of the consumer address



+ remove console, or any debugging code before deploy, they cost gas

+ forge test --debug
    - opcode by opcode debugging
