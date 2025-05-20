pub use starknet::{ClassHash, ContractAddress};

#[starknet::interface]
pub trait ITokenFactory<TContractState> {
    /// Create a new counter contract from the given arguments
    fn create_token_at(
        ref self: TContractState,
        token_name: ByteArray,
        token_symbol: ByteArray,
        default_admin: ContractAddress,
        fixed_supply: u256,
        agent: ContractAddress,
        controller: ContractAddress,
        salt_id: felt252,
    ) -> ContractAddress;

    /// Update the argument
    fn update_owner(ref self: TContractState, owner: ContractAddress);

    /// Update the class hash of the Counter contract to deploy when creating a new counter
    fn update_token_class_hash(ref self: TContractState, token_class_hash: ClassHash);
    fn get_token_class_hash(self: @TContractState) -> ClassHash;
}

#[starknet::contract]
pub mod TokenFactory {
    use core::traits::Into;
    use starknet::{ClassHash, ContractAddress, SyscallResultTrait, syscalls::deploy_syscall};

    #[storage]
    struct Storage {
        /// Store the constructor arguments of the contract to deploy
        owner: ContractAddress,
        /// Store the class hash of the contract to deploy
        token_class_hash: ClassHash,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, token_class_hash: ClassHash) {
        self.owner.write(owner);
        self.token_class_hash.write(token_class_hash);
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        TokenCreated: TokenCreated,
    }


    #[derive(Drop, starknet::Event)]
    struct TokenCreated {
        token_name: ByteArray,
        token_symbol: ByteArray,
        deployed_address: ContractAddress,
        default_admin: ContractAddress,
        fixed_supply: u256,
        agent: ContractAddress,
        controller: ContractAddress,
        salt_id: felt252,
    }


    #[abi(embed_v0)]
    impl Factory of super::ITokenFactory<ContractState> {
        fn create_token_at(
            ref self: ContractState,
            token_name: ByteArray,
            token_symbol: ByteArray,
            default_admin: ContractAddress,
            fixed_supply: u256,
            agent: ContractAddress,
            controller: ContractAddress,
            salt_id: felt252,
        ) -> ContractAddress {
            // Contructor arguments

            let mut constructor_calldata: Array<felt252> = array![];

            token_name.serialize(ref constructor_calldata);
            token_symbol.serialize(ref constructor_calldata);
            default_admin.serialize(ref constructor_calldata);
            fixed_supply.serialize(ref constructor_calldata);
            agent.serialize(ref constructor_calldata);
            controller.serialize(ref constructor_calldata);

            let (deployed_address, _) = deploy_syscall(
                self.token_class_hash.read(), 0, constructor_calldata.span(), false,
            )
                .unwrap_syscall();
            self
                .emit(
                    TokenCreated {
                        token_name: token_name,
                        token_symbol: token_symbol,
                        deployed_address: deployed_address,
                        default_admin: default_admin,
                        fixed_supply: fixed_supply,
                        agent: agent,
                        controller: controller,
                        salt_id: salt_id,
                    },
                );
            deployed_address
        }


        fn update_owner(ref self: ContractState, owner: ContractAddress) {
            self.owner.write(owner);
        }

        fn update_token_class_hash(ref self: ContractState, token_class_hash: ClassHash) {
            self.token_class_hash.write(token_class_hash);
        }

        fn get_token_class_hash(self: @ContractState) -> ClassHash {
            self.token_class_hash.read()
        }
    }
}

