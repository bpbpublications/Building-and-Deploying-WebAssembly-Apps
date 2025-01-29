use near_sdk::borsh::{BorshDeserialize, BorshSerialize};
use near_sdk::{env, near_bindgen, AccountId};

#[near_bindgen]
#[derive(Default, BorshDeserialize, BorshSerialize)]
#[borsh(crate = "near_sdk::borsh")]
pub struct Visitor {
    visitor: Option<AccountId>
}

#[near_bindgen]
impl Visitor {
    pub fn visit(&mut self) {
        let _ = self.visitor.insert(env::signer_account_id());
    }

    pub fn last_visitor(&self) -> Option<AccountId> {
        self.visitor.to_owned()
    }
}
