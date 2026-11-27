//! Parallelism, blocking execution, and cancellation (design D6 / task 5.2).

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

use tokio::sync::{OwnedSemaphorePermit, Semaphore};

use crate::limits::DEFAULT_MAX_PARALLEL_CALLS;

/// Shared gate for in-flight tool calls.
pub struct DispatchGate {
    semaphore: Arc<Semaphore>,
}

impl DispatchGate {
    pub fn new(max_parallel: usize) -> Self {
        Self {
            semaphore: Arc::new(Semaphore::new(max_parallel.max(1))),
        }
    }

    pub fn with_defaults() -> Self {
        Self::new(DEFAULT_MAX_PARALLEL_CALLS)
    }

    pub fn semaphore(&self) -> Arc<Semaphore> {
        Arc::clone(&self.semaphore)
    }
}

/// Acquire a permit, then run `work` on a blocking thread with `cancel`.
pub async fn run_blocking<F, T>(
    semaphore: Arc<Semaphore>,
    cancel: Arc<AtomicBool>,
    work: F,
) -> Result<T, String>
where
    F: FnOnce(Arc<AtomicBool>) -> T + Send + 'static,
    T: Send + 'static,
{
    let permit: OwnedSemaphorePermit = semaphore
        .acquire_owned()
        .await
        .map_err(|_| "dispatch semaphore closed".to_string())?;
    let result = tokio::task::spawn_blocking(move || {
        let out = work(Arc::clone(&cancel));
        drop(permit);
        out
    })
    .await
    .map_err(|e| format!("blocking tool task failed: {e}"))?;
    Ok(result)
}

/// Mark the call cancelled (MCP `notifications/cancelled` or stdin close).
pub fn signal_cancel(cancel: &AtomicBool) {
    cancel.store(true, Ordering::SeqCst);
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::AtomicUsize;
    use std::time::Duration;

    #[tokio::test]
    async fn cancelled_call_sets_handler_flag() {
        let gate = DispatchGate::with_defaults();
        let cancel = Arc::new(AtomicBool::new(false));
        let seen = Arc::new(AtomicBool::new(false));
        let seen_c = Arc::clone(&seen);
        let cancel_for_work = Arc::clone(&cancel);

        let handle = tokio::spawn(run_blocking(
            gate.semaphore(),
            Arc::clone(&cancel),
            move |flag| {
                // Wait until the outer cancel is signalled, then mirror it.
                while !flag.load(Ordering::SeqCst) {
                    std::thread::sleep(Duration::from_millis(5));
                }
                seen_c.store(flag.load(Ordering::SeqCst), Ordering::SeqCst);
                true
            },
        ));

        // Give the blocking task time to start, then cancel.
        tokio::time::sleep(Duration::from_millis(20)).await;
        signal_cancel(&cancel_for_work);
        let ok = handle.await.unwrap().unwrap();
        assert!(ok);
        assert!(seen.load(Ordering::SeqCst));
    }

    #[tokio::test]
    async fn third_concurrent_call_waits() {
        let gate = DispatchGate::new(2);
        let started = Arc::new(AtomicUsize::new(0));
        let release = Arc::new(AtomicBool::new(false));

        let mut handles = Vec::new();
        for _ in 0..3 {
            let sem = gate.semaphore();
            let started_c = Arc::clone(&started);
            let release_c = Arc::clone(&release);
            handles.push(tokio::spawn(run_blocking(
                sem,
                Arc::new(AtomicBool::new(false)),
                move |_cancel| {
                    started_c.fetch_add(1, Ordering::SeqCst);
                    while !release_c.load(Ordering::SeqCst) {
                        std::thread::sleep(Duration::from_millis(5));
                    }
                },
            )));
            // Stagger submissions so the first two grab permits.
            tokio::time::sleep(Duration::from_millis(10)).await;
        }

        tokio::time::sleep(Duration::from_millis(50)).await;
        assert_eq!(
            started.load(Ordering::SeqCst),
            2,
            "third call must wait for a free permit"
        );

        release.store(true, Ordering::SeqCst);
        for h in handles {
            h.await.unwrap().unwrap();
        }
        assert_eq!(started.load(Ordering::SeqCst), 3);
    }
}
