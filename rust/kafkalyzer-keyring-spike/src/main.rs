fn main() {
    let entry = keyring::Entry::new("kafkalyzer-keyring-spike", "probe")
        .expect("create entry");
    match entry.set_password("roundtrip-value") {
        Ok(()) => {
            let got = entry.get_password().expect("get");
            assert_eq!(got, "roundtrip-value");
            entry.delete_credential().expect("delete");
            println!("ok: secret-service round-trip");
        }
        Err(e) => {
            eprintln!("keyring error: {e:?}");
            std::process::exit(2);
        }
    }
}
