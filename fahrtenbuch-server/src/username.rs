use std::error::Error;
use std::fmt;
use std::str::FromStr;

use serde::{de, Deserialize};
use serde::{ser, Serialize};
use sqlx::database::{HasArguments, HasValueRef};

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct Username(String);

impl FromStr for Username {
    type Err = anyhow::Error;

    fn from_str(username: &str) -> Result<Self, Self::Err> {
        Ok(Self(username.trim().to_lowercase()))
    }
}

impl fmt::Display for Username {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        if self.0.len() > 1 {
            write!(
                f,
                "{}{}",
                self.0[..1].to_uppercase(),
                self.0[1..].to_lowercase()
            )
        } else {
            write!(f, "{}", self.0.to_uppercase())
        }
    }
}

impl<'de> Deserialize<'de> for Username {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: de::Deserializer<'de>,
    {
        let s = <&str>::deserialize(deserializer)?;
        Self::from_str(s).map_err(de::Error::custom)
    }
}

impl Serialize for Username {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: ser::Serializer,
    {
        self.to_string().serialize(serializer)
    }
}

impl<'q, DB: sqlx::Database> sqlx::Encode<'q, DB> for Username
where
    String: sqlx::Encode<'q, DB>,
{
    fn encode_by_ref(
        &self,
        buf: &mut <DB as HasArguments<'q>>::ArgumentBuffer,
    ) -> sqlx::encode::IsNull {
        self.0.encode_by_ref(buf)
    }
}

impl<'r, DB: sqlx::Database> sqlx::Decode<'r, DB> for Username
where
    String: sqlx::Decode<'r, DB>,
{
    fn decode(
        value: <DB as HasValueRef<'r>>::ValueRef,
    ) -> Result<Self, Box<dyn Error + Sync + Send>> {
        let string = String::decode(value)?;
        Ok(Self(string))
    }
}

impl<DB: sqlx::Database> sqlx::Type<DB> for Username
where
    String: sqlx::Type<DB>,
{
    // Required method
    fn type_info() -> <DB as sqlx::Database>::TypeInfo {
        String::type_info()
    }
}
