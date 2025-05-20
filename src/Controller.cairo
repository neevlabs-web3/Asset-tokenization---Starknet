#[starknet::contract]
pub mod Controller {
    use tokenization::AssetToken::AssetToken::{IAssetTokenDispatcher, IAssetTokenDispatcherTrait};
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::storage::{Map, StoragePathEntry};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ContractAddress};
    use starknet::{get_caller_address, get_contract_address};
    #[starknet::interface]
    pub trait IController<TContractState> {
        fn token_mint(
            ref self: TContractState,
            token: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
            action_id: felt252,
        );

        fn token_batch_mint(
            ref self: TContractState,
            token: ContractAddress,
            recipients: Span<ContractAddress>,
            amounts: Span<u256>,
            action_id: felt252,
        );

        fn token_burn(
            ref self: TContractState,
            token: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
            action_id: felt252,
        );

        fn token_freeze(
            ref self: TContractState,
            token: ContractAddress,
            user: ContractAddress,
            action_id: felt252,
        );
        fn token_unfreeze(
            ref self: TContractState,
            token: ContractAddress,
            user: ContractAddress,
            action_id: felt252,
        );
        fn is_frozen_account(
            self: @TContractState, token: ContractAddress, user: ContractAddress,
        ) -> bool;

        fn token_add_default_admin(
            ref self: TContractState,
            token: ContractAddress,
            admin: ContractAddress,
            action_id: felt252,
        );

        fn token_add_agent(
            ref self: TContractState,
            token: ContractAddress,
            agent: ContractAddress,
            action_id: felt252,
        );
        fn token_remove_agent(
            ref self: TContractState,
            token: ContractAddress,
            agent: ContractAddress,
            action_id: felt252,
        );
        fn is_token_agent(
            self: @TContractState, token: ContractAddress, agent: ContractAddress,
        ) -> bool;


        fn is_user_whitelisted(
            self: @TContractState, token: ContractAddress, user: ContractAddress,
        ) -> bool;
        fn whitelist_user(
            ref self: TContractState,
            token: ContractAddress,
            user: ContractAddress,
            action_id: felt252,
        );
        fn remove_whitelisted_user(
            ref self: TContractState,
            token: ContractAddress,
            user: ContractAddress,
            action_id: felt252,
        );


        fn set_admin_fee(
            ref self: TContractState, fee: u256, token: ContractAddress, action_id: felt252,
        );

        fn deposit(
            ref self: TContractState,
            sender: ContractAddress,
            stablecoin: ContractAddress,
            stablecoin_amount: u256,
            asset: ContractAddress,
            asset_amount: u256,
            order_id: felt252,
        );
        fn settlement(ref self: TContractState, order_id: felt252, action_id: felt252);
    }


    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);


    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;


    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        order_created: Map<felt252, bool>, 
        investor_orders: Map<felt252, InvestorOrder>,
        received_amount: Map<felt252, u256>, 
        owner: ContractAddress,
        admin_fee: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct Deposited {
        #[key]
        investor: ContractAddress,
        token: ContractAddress,
        amount: u256,
        tokens: u256,
        order_id: felt252,
        coin: ContractAddress,
    }


    #[derive(Drop, Debug, starknet::Store)]
    struct InvestorOrder {
        investor: ContractAddress,
        asset: ContractAddress,
        value: u256,
        tokens: u256,
        coin: ContractAddress,
        status: bool,
    }

    #[derive(Drop, starknet::Event)]
    struct OrderSettled {
        amount: u256,
        tokens: u256,
        admin_fee: u256,
        order_id: felt252,
        action_id: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct AgentAdded {
        agent: ContractAddress,
        token_address: ContractAddress,
        action_id: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct AgentRemoved {
        agent: ContractAddress,
        token_address: ContractAddress,
        action_id: felt252,
    }


    #[derive(Drop, starknet::Event)]
    struct WhitelistUser {
        user: ContractAddress,
        whitelisted: bool,
        action_id: felt252,
    }


    #[derive(Drop, starknet::Event)]
    struct FrozenUser {
        user: ContractAddress,
        frozen: bool,
        action_id: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct BatchMinted {
        token: ContractAddress,
        recipient: Span<ContractAddress>,
        amount: Span<u256>,
        action_id: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct Minted {
        token: ContractAddress,
        recipient: ContractAddress,
        amount: u256,
        action_id: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct Burned {
        token: ContractAddress,
        recipient: ContractAddress,
        amount: u256,
        action_id: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct DefaultAdminAdded {
        token: ContractAddress,
        admin: ContractAddress,
        action_id: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct AdminFeeUpdated {
        admin_fee: u256,
        action_id: felt252,
    }


    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        Deposited: Deposited,
        Frozen: FrozenUser,
        Whitelisted: WhitelistUser, // New event
        AgentAdded: AgentAdded,
        AgentRemoved: AgentRemoved,
        Minted: Minted,
        BatchMinted: BatchMinted,
        Burned: Burned,
        DefaultAdminAdded: DefaultAdminAdded,
        AdminFeeUpdated: AdminFeeUpdated,
        OrderSettled: OrderSettled,
    }
    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress,_fee:u256) {
        // Initialize the owner using OwnableComponent
        self.ownable.initializer(owner);
        self.owner.write(owner);
        self.admin_fee.write(_fee);
    }

    #[abi(embed_v0)]
    impl ControllerImpl of IController<ContractState> {
        //-------------------------------TOKEN FUNCTIONS-------------------------------------

        fn token_mint(
            ref self: ContractState,
            token: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
            action_id: felt252,
        ) {
            let asset_token_dispatcher = IAssetTokenDispatcher { contract_address: token };
            asset_token_dispatcher.mint(recipient, amount);
            self
                .emit(
                    Minted {
                        token: token, recipient: recipient, amount: amount, action_id: action_id,
                    },
                );
        }

        fn token_batch_mint(
            ref self: ContractState,
            token: ContractAddress,
            recipients: Span<ContractAddress>,
            amounts: Span<u256>,
            action_id: felt252,
        ) {
            let recipients_data = recipients.clone();
            let amounts_data = amounts.clone();
            let asset_token_dispatcher = IAssetTokenDispatcher { contract_address: token };
            asset_token_dispatcher.batch_mint(recipients, amounts);
            self
                .emit(
                    BatchMinted {
                        token, recipient: recipients_data, amount: amounts_data, action_id,
                    },
                );
        }

        fn token_burn(
            ref self: ContractState,
            token: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
            action_id: felt252,
        ) {
            let asset_token_dispatcher = IAssetTokenDispatcher { contract_address: token };
            asset_token_dispatcher.burn(recipient, amount);
            self
                .emit(
                    Burned {
                        token: token, recipient: recipient, amount: amount, action_id: action_id,
                    },
                );
        }
        fn token_freeze(
            ref self: ContractState,
            token: ContractAddress,
            user: ContractAddress,
            action_id: felt252,
        ) {
            let asset_token_dispatcher = IAssetTokenDispatcher { contract_address: token };
            asset_token_dispatcher.freeze(user);
            self.emit(FrozenUser { user: user, frozen: true, action_id: action_id })
        }

        fn token_unfreeze(
            ref self: ContractState,
            token: ContractAddress,
            user: ContractAddress,
            action_id: felt252,
        ) {
            let asset_token_dispatcher = IAssetTokenDispatcher { contract_address: token };
            asset_token_dispatcher.unfreeze(user);
            self.emit(FrozenUser { user: user, frozen: false, action_id: action_id })
        }

        fn is_frozen_account(
            self: @ContractState, token: ContractAddress, user: ContractAddress,
        ) -> bool {
            let asset_token_dispatcher = IAssetTokenDispatcher { contract_address: token };
            return asset_token_dispatcher.isAccountFreezed(user);
        }


        //------------------------------AGENT FUNCTIONS-------------------------------------

        fn token_add_agent(
            ref self: ContractState,
            token: ContractAddress,
            agent: ContractAddress,
            action_id: felt252,
        ) {
            let asset_token_dispatcher = IAssetTokenDispatcher { contract_address: token };
            asset_token_dispatcher.add_token_agent(agent);
            self.emit(AgentRemoved { agent: agent, token_address: token, action_id });
        }

        fn token_remove_agent(
            ref self: ContractState,
            token: ContractAddress,
            agent: ContractAddress,
            action_id: felt252,
        ) {
            let asset_token_dispatcher = IAssetTokenDispatcher { contract_address: token };
            asset_token_dispatcher.remove_token_agent(agent);
            self.emit(AgentRemoved { agent: agent, token_address: token, action_id });
        }

        fn is_token_agent(
            self: @ContractState, token: ContractAddress, agent: ContractAddress,
        ) -> bool {
            let asset_token_dispatcher = IAssetTokenDispatcher { contract_address: token };
            return asset_token_dispatcher.isTokenAgent(agent);
        }

        fn token_add_default_admin(
            ref self: ContractState,
            token: ContractAddress,
            admin: ContractAddress,
            action_id: felt252,
        ) {
            let asset_token_dispatcher = IAssetTokenDispatcher { contract_address: token };
            asset_token_dispatcher.add_admin_role(admin);
            self.emit(DefaultAdminAdded { token: token, admin: admin, action_id })
        }

        //-------------------------------WHITELISTING FUNCTIONS-------------------------------------

        fn whitelist_user(
            ref self: ContractState,
            token: ContractAddress,
            user: ContractAddress,
            action_id: felt252,
        ) {
            let asset_token_dispatcher = IAssetTokenDispatcher { contract_address: token };
            asset_token_dispatcher.add_to_whitelist(user);
            self.emit(WhitelistUser { user: user, whitelisted: true, action_id: action_id });
        }

        fn remove_whitelisted_user(
            ref self: ContractState,
            token: ContractAddress,
            user: ContractAddress,
            action_id: felt252,
        ) {
            let asset_token_dispatcher = IAssetTokenDispatcher { contract_address: token };
            asset_token_dispatcher.remove_from_whitelist(user);
            self.emit(WhitelistUser { user: user, whitelisted: false, action_id: action_id });
        }

        fn is_user_whitelisted(
            self: @ContractState, token: ContractAddress, user: ContractAddress,
        ) -> bool {
            let asset_token_dispatcher = IAssetTokenDispatcher { contract_address: token };
            return asset_token_dispatcher.is_whitelisted(user);
        }
        //-------------------------------ESCROW FUNCTIONS-------------------------------------

        fn deposit(
            ref self: ContractState,
            sender: ContractAddress,
            stablecoin: ContractAddress,
            stablecoin_amount: u256,
            asset: ContractAddress,
            asset_amount: u256,
            order_id: felt252,
        ) {
            // Validations
            // assert!(!token.is_non_zero(), ' Zero Address not allowed');

            assert!(stablecoin_amount > 0, "Amount should be greater than 0");
            let caller = get_caller_address();

            // Check if the investor is whitelisted
            let asset_token_dispatcher = IAssetTokenDispatcher { contract_address: asset };
            let coin_dispatcher = IERC20Dispatcher { contract_address: stablecoin };

            let is_whitelisted = asset_token_dispatcher.is_whitelisted(caller);
            assert!(is_whitelisted, "Investor not whitelisted");

            // Check if the order is already created
            let order_exists: bool = self.order_created.read(order_id);
            assert!(!order_exists, "Order Already Created");

            // Store the order details
            let investor_order: InvestorOrder = InvestorOrder {
                investor: caller,
                asset: asset,
                value: stablecoin_amount,
                tokens: asset_amount,
                coin: stablecoin,
                status: false,
            };

            self.investor_orders.entry(order_id).write(investor_order);
            self.received_amount.write(order_id, stablecoin_amount);
            self.order_created.write(order_id, true);

            coin_dispatcher.transfer_from(sender, get_contract_address(), stablecoin_amount);

            // Emit the AmountReceived event
            self
                .emit(
                    Deposited {
                        investor: caller,
                        token: asset,
                        amount: stablecoin_amount,
                        tokens: asset_amount,
                        order_id: order_id,
                        coin: stablecoin,
                    },
                );
        }

        fn settlement(ref self: ContractState, order_id: felt252, action_id: felt252) {
            let order = self.investor_orders.read(order_id);
            let token = order.asset;
            let asset_token_dispatcher = IAssetTokenDispatcher { contract_address: token };
            assert!(asset_token_dispatcher.isTokenAgent(get_caller_address()), "Invalid Issuer");
            assert!(self.investor_orders.read(order_id).status, "Order already settled");

            // Calculate admin fee amount
            let admin_fee_amount = (order.value * self.admin_fee.read() / 100);
            let final_amount = order.value - admin_fee_amount;

            let stablecoin_address = order.coin;
            let coin_dispatcher = IERC20Dispatcher { contract_address: stablecoin_address };

            coin_dispatcher.transfer(get_caller_address(), final_amount);
            coin_dispatcher.transfer(self.owner.read(), admin_fee_amount);
            self
                .emit(
                    OrderSettled {
                        amount: admin_fee_amount,
                        tokens: final_amount,
                        admin_fee: self.admin_fee.read(),
                        order_id: order_id,
                        action_id: action_id,
                    },
                )
        }
        fn set_admin_fee(
            ref self: ContractState, fee: u256, token: ContractAddress, action_id: felt252,
        ) {
            let asset_token_dispatcher = IAssetTokenDispatcher { contract_address: token };
            assert!(asset_token_dispatcher.isTokenAgent(get_caller_address()), "Not agent");

            self.admin_fee.write(fee);
            self.emit(AdminFeeUpdated { admin_fee: fee, action_id: action_id })
        }
    }
}
