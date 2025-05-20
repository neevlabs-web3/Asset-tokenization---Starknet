#[starknet::contract]
mod AssetToken {
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::access::accesscontrol::DEFAULT_ADMIN_ROLE;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::security::pausable::PausableComponent;
    use openzeppelin::token::erc20::ERC20Component;
    pub use starknet::ClassHash;
    use starknet::ContractAddress;
    use starknet::storage::{Map};
    use starknet::{get_contract_address};
    pub const AGENT_ROLE: felt252 = selector!("AGENT_ROLE");
    use core::traits::Into;

    #[starknet::interface]
    pub trait IAssetToken<TContractState> {
        fn freeze(ref self: TContractState, user: ContractAddress);
        fn unfreeze(ref self: TContractState, user: ContractAddress);
        fn mint(ref self: TContractState, recipient: ContractAddress, amount: u256);
        fn burn(ref self: TContractState, user: ContractAddress, value: u256);
        fn isAccountFreezed(self: @TContractState, user: ContractAddress) -> bool;

        fn batch_mint(
            ref self: TContractState, recipients: Span<ContractAddress>, amounts: Span<u256>,
        );
        fn batch_burn(
            ref self: TContractState, recipients: Span<ContractAddress>, amounts: Span<u256>,
        );
        fn batch_freeze(ref self: TContractState, user: Span<ContractAddress>);
        fn batch_unfreeze(ref self: TContractState, user: Span<ContractAddress>);
        fn batch_whitelist(ref self: TContractState, user: Span<ContractAddress>);
        fn batch_remove_from_whitelist(ref self: TContractState, user: Span<ContractAddress>);

        fn add_token_agent(ref self: TContractState, agent_address: ContractAddress);
        fn remove_token_agent(ref self: TContractState, agent_address: ContractAddress);
        fn isTokenAgent(self: @TContractState, user: ContractAddress) -> bool;

        fn add_to_whitelist(ref self: TContractState, user: ContractAddress);
        fn remove_from_whitelist(ref self: TContractState, user: ContractAddress);
        fn is_whitelisted(self: @TContractState, user: ContractAddress) -> bool;

        fn get_agent_role(self: @TContractState) -> felt252;
        fn get_admin_role(self: @TContractState) -> felt252;

        fn add_admin_role(ref self: TContractState, user: ContractAddress);
        fn add_controller(ref self: TContractState, controller: ContractAddress);
    }
    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: PausableComponent, storage: pausable, event: PausableEvent);
    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);


    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    #[abi(embed_v0)]
    impl PausableImpl = PausableComponent::PausableImpl<ContractState>;
    #[abi(embed_v0)]
    impl AccessControlMixinImpl =
        AccessControlComponent::AccessControlMixinImpl<ContractState>;

    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;
    impl PausableInternalImpl = PausableComponent::InternalImpl<ContractState>;
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;


    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        #[substorage(v0)]
        pausable: PausableComponent::Storage,
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        frozen: Map::<ContractAddress, bool>,
        whitelist: Map<ContractAddress, bool>,
        controller: ContractAddress,
    }


    #[derive(Drop, starknet::Event)]
    struct AgentAdded {
        agent: ContractAddress,
        token_address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct AgentRemoved {
        agent: ContractAddress,
        token_address: ContractAddress,
    }


    #[derive(Drop, starknet::Event)]
    struct WhitelistUser {
        user: ContractAddress,
        whitelisted: bool,
    }


    #[derive(Drop, starknet::Event)]
    struct FrozenUser {
        user: ContractAddress,
        frozen: bool,
    }


    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        PausableEvent: PausableComponent::Event,
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        Frozen: FrozenUser,
        Whitelisted: WhitelistUser,
        AgentAdded: AgentAdded,
        AgentRemoved: AgentRemoved,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        tokenName: ByteArray,
        tokenSymbol: ByteArray,
        default_admin: ContractAddress,
        fixed_supply: u256,
        agent: ContractAddress,
        controller: ContractAddress,
    ) {
        self.erc20.initializer(tokenName, tokenSymbol);
        self.accesscontrol.initializer();
        self.accesscontrol._grant_role(DEFAULT_ADMIN_ROLE, default_admin);
        self.accesscontrol._grant_role(DEFAULT_ADMIN_ROLE, controller);
        self.accesscontrol._grant_role(AGENT_ROLE, agent);
        self.accesscontrol._grant_role(AGENT_ROLE, controller);

        self.whitelist.write(controller, true);
        self.whitelist.write(agent, true);
        self.whitelist.write(default_admin, true);
    }

    #[abi(embed_v0)]
    impl AssetTokenImpl of IAssetToken<ContractState> {
        fn add_token_agent(ref self: ContractState, agent_address: ContractAddress) {
            self.accesscontrol.assert_only_role(DEFAULT_ADMIN_ROLE);
            self.accesscontrol._grant_role(AGENT_ROLE, agent_address);
            self.emit(AgentAdded { agent: agent_address, token_address: get_contract_address() });
        }


        fn remove_token_agent(ref self: ContractState, agent_address: ContractAddress) {
            self.accesscontrol.assert_only_role(DEFAULT_ADMIN_ROLE);
            self.accesscontrol.revoke_role(AGENT_ROLE, agent_address);
            self.emit(AgentRemoved { agent: agent_address, token_address: get_contract_address() });
        }


        fn isTokenAgent(self: @ContractState, user: ContractAddress) -> bool {
            return self.accesscontrol.has_role(AGENT_ROLE, user);
        }

        fn burn(ref self: ContractState, user: ContractAddress, value: u256) {
            self.accesscontrol.assert_only_role(AGENT_ROLE);
            self.erc20.burn(user, value);
        }


        fn mint(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            self.accesscontrol.assert_only_role(AGENT_ROLE);
            assert!(self.is_whitelisted(recipient), "User is not whitelisted");
            self.erc20.mint(recipient, amount);
        }

        fn freeze(ref self: ContractState, user: ContractAddress) {
            self.accesscontrol.assert_only_role(AGENT_ROLE);
            let is_frozen_account: bool = self.isAccountFreezed(user);
            assert!(
                is_frozen_account, "Already Frozen",
            ); // Ensure frozen status is checked correctly
            self.frozen.write(user, true);
            self.emit(FrozenUser { user: user, frozen: true })
        }


        fn unfreeze(ref self: ContractState, user: ContractAddress) {
            self.accesscontrol.assert_only_role(AGENT_ROLE);
            let is_frozen_account: bool = self.isAccountFreezed(user);
            assert!(
                !is_frozen_account, "Already UnFrozen",
            ); // Ensure frozen status is checked correctly
            self.frozen.write(user, false);
            self.emit(FrozenUser { user: user, frozen: false })
        }

        fn batch_mint(
            ref self: ContractState, recipients: Span<ContractAddress>, amounts: Span<u256>,
        ) {
            assert!(recipients.len() == amounts.len(), "Mismatched arrays");

            for i in 0..recipients.len() {
                let recipient: ContractAddress = *recipients[i];
                let amount: u256 = *amounts[i];
                // Log whitelist status for debugging
                let is_whitelisted: bool = self.is_whitelisted(recipient);
                self.emit(WhitelistUser { user: recipient, whitelisted: is_whitelisted });

                assert!(
                    is_whitelisted, "not whitelisted in batch",
                ); // Ensure whitelist status is checked correctly

                self.erc20.mint(recipient, amount);
            }
        }

        fn batch_burn(
            ref self: ContractState, recipients: Span<ContractAddress>, amounts: Span<u256>,
        ) {
            assert!(recipients.len() == amounts.len(), "Mismatched arrays");

            for i in 0..recipients.len() {
                let recipient: ContractAddress = *recipients[i];
                let amount: u256 = *amounts[i];

                // Mint tokens for each recipient
                self.burn(recipient, amount);
            }
        }

        fn batch_freeze(ref self: ContractState, user: Span<ContractAddress>) {
            for i in 0..user.len() {
                let users: ContractAddress = *user[i];
                // Batch Freeze tokens for each user
                self.freeze(users);
            }
        }

        fn batch_unfreeze(ref self: ContractState, user: Span<ContractAddress>) {
            for i in 0..user.len() {
                let users: ContractAddress = *user[i];
                // Batch Unfreeze tokens for each user
                self.unfreeze(users);
            }
        }

        fn batch_whitelist(ref self: ContractState, user: Span<ContractAddress>) {
            for i in 0..user.len() {
                let users: ContractAddress = *user[i];
                // Batch Whitelist user
                self.add_to_whitelist(users);
            }
        }

        fn batch_remove_from_whitelist(ref self: ContractState, user: Span<ContractAddress>) {
            for i in 0..user.len() {
                let users: ContractAddress = *user[i];
                // Batch remove whitelisted user
                self.remove_from_whitelist(users);
            }
        }


        fn isAccountFreezed(self: @ContractState, user: ContractAddress) -> bool {
            return self.frozen.read(user);
        }

        fn add_to_whitelist(ref self: ContractState, user: ContractAddress) {
            self.accesscontrol.assert_only_role(AGENT_ROLE);
            self.whitelist.write(user, true);
            self.emit(WhitelistUser { user: user, whitelisted: true });
        }


        fn remove_from_whitelist(ref self: ContractState, user: ContractAddress) {
            self.accesscontrol.assert_only_role(AGENT_ROLE);
            self.whitelist.write(user, false);
            self.emit(WhitelistUser { user: user, whitelisted: false });
        }


        fn is_whitelisted(self: @ContractState, user: ContractAddress) -> bool {
            return self.whitelist.read(user);
        }


        fn get_agent_role(self: @ContractState) -> felt252 {
            return selector!("AGENT_ROLE");
        }


        fn get_admin_role(self: @ContractState) -> felt252 {
            return selector!("DEFAULT_ADMIN_ROLE");
        }

        fn add_admin_role(ref self: ContractState, user: ContractAddress) {
            self.accesscontrol.assert_only_role(AGENT_ROLE);
            self.accesscontrol._grant_role(DEFAULT_ADMIN_ROLE, user);
        }

        fn add_controller(ref self: ContractState, controller: ContractAddress) {
            self.accesscontrol.assert_only_role(AGENT_ROLE);
            self.controller.write(controller);
            self.accesscontrol._grant_role(DEFAULT_ADMIN_ROLE, controller);
        }
    }

    impl ERC20HooksImpl of ERC20Component::ERC20HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC20Component::ComponentState<ContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
        ) {
            let contract_state = ERC20Component::HasComponent::get_contract(@self);
            let mut state = ERC20Component::HasComponent::get_contract(@self);
            contract_state.pausable.assert_not_paused();

            let contract_address = get_contract_address();

            if from != contract_address {
                let from_frozen = state.frozen.read(from);
                let from_whitelisted = state.whitelist.read(from);

                assert!(!from_frozen, "Sender account is frozen");
                assert!(from_whitelisted, "Sender is NOT whitelisted");
            }

            let recipient_frozen = state.frozen.read(recipient);
            let recipient_whitelisted = state.whitelist.read(recipient);

            assert!(!recipient_frozen, "Recipient account is frozen");
            assert!(recipient_whitelisted, "Recipient is NOT whitelisted");
        }

        fn after_update(
            ref self: ERC20Component::ComponentState<ContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
        ) {}
    }
}
