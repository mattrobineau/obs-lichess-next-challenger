#[macro_use]
extern crate lazy_static;

use log::{error, info, warn};
use log4rs;
use serde_json::Value;
use std::ffi::{CStr, CString};
use std::sync::Mutex;
use std::thread;
use tokio::runtime::Runtime;
use tokio_util::io::StreamReader;

struct State {
    enabled: bool,
    next_challenger: String,
    challenger_count: usize,
}

lazy_static! {
    static ref STATE: Mutex<State> = Mutex::new(State {
        enabled: true,
        next_challenger: "".to_string(),
        challenger_count: 0,
    });
}

#[no_mangle]
pub extern "C" fn get_next_challenger() -> *mut libc::c_char {
    let state = STATE.lock().unwrap();
    CString::new(state.next_challenger.to_string())
        .unwrap()
        .into_raw()
}

#[no_mangle]
fn connect_to_feed(token: *const libc::c_char) {
    // Convert c string to rust str;
    let tok = convert_to_string(token).unwrap();
    let rt = Runtime::new().unwrap();
    let tok_clone = tok.clone();
    thread::spawn(move || {
        rt.block_on(async {
            // TODO Figure out how to display errors? Or maybe just disable plugin?
            get_stream_events(tok.to_string()).await.unwrap();
        });
    });

    let rt = Runtime::new().unwrap();
    rt.block_on(async {
        match fetch_next_challenger(&tok_clone).await {
            Ok(challenger) => {
                let mut state = STATE.lock().unwrap();
                (state.next_challenger, state.challenger_count) = challenger;
            }
            _ => (),
        };
    });
}

#[no_mangle]
fn terminate() {
    STATE.lock().unwrap().enabled = false;
}

fn convert_to_string(s: *const libc::c_char) -> Result<String, Box<dyn std::error::Error>> {
    let c_str = unsafe {
        assert!(!s.is_null());
        CStr::from_ptr(s)
    };

    Ok(String::from(c_str.to_str()?))
}

async fn get_stream_events(token: String) -> Result<(), Box<dyn std::error::Error>> {
    let client = reqwest::Client::new();
    let response = client
        .get("https://lichess.org/api/stream/event")
        .header(reqwest::header::AUTHORIZATION, format!("Bearer {}", token))
        .send()
        .await?;

    use futures::stream::TryStreamExt;
    let reader = StreamReader::new(
        response
            .bytes_stream()
            .map_err(|e| std::io::Error::new(std::io::ErrorKind::InvalidData, e)),
    );

    use tokio::io::AsyncBufReadExt;
    let mut lines = reader.lines();

    while let Some(json) = lines.next_line().await? {
        let mut state = STATE.lock()?;

        if !state.enabled {
            break;
        }

        if json == "" {
            continue;
        }

        let v: Value = serde_json::from_str(&json)?;

        let event_type = v["type"].to_string();
        match event_type.as_str() {
            "gameStart" => {
                (state.next_challenger, state.challenger_count) =
                    fetch_next_challenger(&token).await?;
            }
            "challengeCanceled" => {
                state.challenger_count -= 1;
                if v["challenge"]["challenger"]["name"].to_string() == state.next_challenger {
                    (state.next_challenger, _) = fetch_next_challenger(&token).await?;
                }
            }
            "challenge" => {
                if state.challenger_count == 0 {
                    (state.next_challenger, state.challenger_count) =
                        fetch_next_challenger(&token).await?;
                } else {
                    state.challenger_count += 1;
                }
            }
            _ => {}
        };
    }

    Ok(())
}

async fn fetch_next_challenger(
    token: &String,
) -> Result<(String, usize), Box<dyn std::error::Error>> {
    let client = reqwest::Client::new();
    let response = client
        .get("https://lichess.org/api/challenge")
        .header(reqwest::header::AUTHORIZATION, format!("Bearer {}", token))
        .send()
        .await?;

    let json = response.text().await?;
    let v: Value = serde_json::from_str(&json)?;

    let name: String = match &v["in"][0]["challenger"]["name"].as_str() {
        Some(s) => s.to_string(),
        None => "".to_string(),
    };

    let count = match &v["in"] {
        Value::Array(arr) => arr.len(),
        _ => 0,
    };

    if *name == Value::Null {
        Ok(("".to_string(), count))
    } else {
        Ok((name, count))
    }
}
