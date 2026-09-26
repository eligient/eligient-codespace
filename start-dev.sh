#!/usr/bin/env bash
# Starts the backend (uvicorn) and waits for it to accept connections,
# then starts the frontend (next dev). Ctrl+C stops both.
script_folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
workspaces_folder="$(cd "${script_folder}/.." && pwd)"
backend_dir="${workspaces_folder}/backend"
frontend_dir="${workspaces_folder}/frontend"
backend_port="${PORT:-8000}"
wait_seconds="${BACKEND_WAIT_SECONDS:-120}"

backend_pid=""

cleanup() {
    trap - EXIT INT TERM
    echo
    echo "Shutting down..."
    if [ -n "${backend_pid}" ] && kill -0 "${backend_pid}" 2>/dev/null; then
        # Kill the whole process group so uvicorn's reloader children go too
        kill -- -"${backend_pid}" 2>/dev/null || kill "${backend_pid}" 2>/dev/null
    fi
    wait 2>/dev/null
}
trap cleanup EXIT INT TERM

for dir in "${backend_dir}" "${frontend_dir}"; do
    if [ ! -d "${dir}" ]; then
        echo "Missing directory: ${dir}" >&2
        exit 1
    fi
done

echo "Starting backend on port ${backend_port}..."
cd "${backend_dir}" || exit 1
setsid uv run uvicorn main:app --reload --host 0.0.0.0 --port "${backend_port}" &
backend_pid=$!

echo "Waiting for backend to be ready (up to ${wait_seconds}s)..."
elapsed=0
until (echo > "/dev/tcp/127.0.0.1/${backend_port}") 2>/dev/null; do
    if ! kill -0 "${backend_pid}" 2>/dev/null; then
        echo "Backend exited before becoming ready." >&2
        exit 1
    fi
    if [ "${elapsed}" -ge "${wait_seconds}" ]; then
        echo "Timed out waiting for backend on port ${backend_port}." >&2
        exit 1
    fi
    sleep 1
    elapsed=$((elapsed + 1))
done
echo "Backend is up."

echo "Starting frontend..."
cd "${frontend_dir}" || exit 1
npm run dev
