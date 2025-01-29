use std::collections::HashMap;

use near_sdk::borsh::{BorshDeserialize, BorshSerialize};
use near_sdk::env::signer_account_id;
use near_sdk::store::LookupMap;
use near_sdk::{env, near_bindgen, AccountId, NearToken, PanicOnDefault};

#[derive(BorshDeserialize, BorshSerialize, PartialEq, Clone)]
#[borsh(crate = "near_sdk::borsh")]
pub enum Permission {
    Owner,
    Contributor,
    Reader,
}

#[near_bindgen]
#[derive(PanicOnDefault, BorshDeserialize, BorshSerialize)]
#[borsh(crate = "near_sdk::borsh")]
pub struct AccessKeyManagement {
    resources: LookupMap<String, HashMap<AccountId, Permission>>,
    tokens: LookupMap<Vec<u8>, AccountId>,
}

#[near_bindgen]
impl AccessKeyManagement {
    #[init(ignore_state)]
    pub fn init() -> Self {
        let contract = Self {
            resources: LookupMap::new(b"r".to_vec()),
            tokens: LookupMap::new(b"t".to_vec()),
        };
        contract
    }

    #[payable]
    pub fn register_resource(&mut self, resource_id: String) {
        if env::attached_deposit() != NearToken::from_millinear(100) {
            env::panic_str("You must deposit 0.1 NEAR to register a resource");
        }
        if self.resources.contains_key(&resource_id) {
            env::panic_str("Resource already exists");
        }
        let mut access_map: HashMap<AccountId, Permission> = HashMap::new();
        access_map.insert(env::signer_account_id(), Permission::Owner);
        self.resources.insert(resource_id, access_map);
    }

    pub fn grant_permission_to_resource(
        &mut self,
        resource_id: String,
        account_id: AccountId,
        permission: String,
    ) {
        let mut resource = self.resources.get(&resource_id).unwrap().clone();
        if resource.get(&signer_account_id()).unwrap().clone() != Permission::Owner {
            env::panic_str("Must be owner to grant permissions to resource");
        }
        resource.insert(
            account_id,
            match permission.as_str() {
                "owner" => Permission::Owner,
                "contributor" => Permission::Contributor,
                "reader" => Permission::Reader,
                _ => env::panic_str("Unknown permission type"),
            },
        );
        self.resources.insert(resource_id, resource);
    }

    pub fn get_permission_for_resource(
        &self,
        resource_id: String,
        account_id: AccountId,
    ) -> String {
        match self
            .resources
            .get(&resource_id)
            .unwrap()
            .get(&account_id)
            .unwrap()
            .clone()
        {
            Permission::Owner => "owner".to_string(),
            Permission::Contributor => "contributor".to_string(),
            Permission::Reader => "reader".to_string(),
        }
    }

    pub fn register_token(&mut self, token_hash: Vec<u8>, signature: Vec<u8>) {
        let mut pk_array: [u8; 32] = [0u8; 32];
        pk_array.copy_from_slice(&env::signer_account_pk().as_bytes()[1..33]);

        if !env::ed25519_verify(
            signature.as_slice().try_into().unwrap(),
            token_hash.as_slice(),
            &pk_array,
        ) {
            env::panic_str("Invalid token signature");
        }
        self.tokens
            .insert(token_hash.to_vec(), env::signer_account_id());
    }

    pub fn get_token_permission_for_resource(
        &self,
        token_hash: Vec<u8>,
        resource_id: String,
    ) -> String {
        let account_id = self.tokens.get(token_hash.as_slice()).unwrap().clone();
        return self.get_permission_for_resource(resource_id, account_id);
    }
}

#[cfg(test)]
pub mod tests {
    use near_sdk::{
        test_utils::{accounts, VMContextBuilder},
        testing_env,
    };

    use super::*;

    #[test]
    fn test_register_resource() {
        testing_env!(VMContextBuilder::new()
            .signer_account_id(accounts(0))
            .attached_deposit(NearToken::from_millinear(100))
            .build());

        let mut contract = AccessKeyManagement::init();
        contract.register_resource("testresource".to_string());
        assert_eq!(
            "owner",
            contract.get_permission_for_resource("testresource".to_string(), accounts(0))
        );
    }

    #[test]
    fn test_grant_permission_to_resource() {
        testing_env!(VMContextBuilder::new()
            .signer_account_id(accounts(0))
            .attached_deposit(NearToken::from_millinear(100))
            .build());

        let mut contract = AccessKeyManagement::init();
        const RESOURCE_ID: &str = "testresource2";
        contract.register_resource(RESOURCE_ID.to_string());
        contract.grant_permission_to_resource(
            RESOURCE_ID.to_string(),
            accounts(1),
            "reader".to_string(),
        );
        assert_eq!(
            "reader",
            contract.get_permission_for_resource(RESOURCE_ID.to_string(), accounts(1))
        );
        testing_env!(VMContextBuilder::new()
            .signer_account_id(accounts(1))
            .build());
        let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
            contract.grant_permission_to_resource(
                RESOURCE_ID.to_string(),
                accounts(2),
                "contributor".to_string(),
            )
        }));

        assert!(result.is_err());
        if let Err(err) = result {
            if let Some(panic_msg) = err.downcast_ref::<String>() {
                assert!(panic_msg.contains("Must be owner to grant permissions to resource"));
            } else {
                panic!("Unexpected panic message type.");
            }
        }
    }
}
