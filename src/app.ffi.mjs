import { Ok, Error } from "./gleam.mjs";

export function get_localstorage(key) {
  const json = window.localStorage.getItem(key);

  if (json === null) return new Error(undefined);

  try {
    return new Ok(json);
  } catch {
    return new Error(undefined);
  }
}

export function count_localstorage() {
  return window.localStorage.length;
}

export function set_localstorage(key, json) {
  window.localStorage.setItem(key, json);
}

export async function share_results(shareData) {
  if (
    navigator.share &&
    /Mobi|Android|iPhone|iPad|iPod/i.test(navigator.userAgent)
  ) {
    navigator.share(shareData).catch(console.error);
  } else {
    await navigator.clipboard.writeText(`${shareData.text} ${shareData.url}`);
    alert("Data copied to clipboard");
  }
}
