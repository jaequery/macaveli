"use client";

import { useEffect } from "react";

// The site's only client JS, all progressive enhancement: nav hairline on
// scroll, scroll-reveal for `.rv`, and real ⌃ ⌘ ⇧ presses sinking the hero
// keycaps. Content is fully visible and usable without it.
export function SiteEffects() {
  useEffect(() => {
    const nav = document.getElementById("nav");
    const onScroll = () => nav?.classList.toggle("scrolled", window.scrollY > 8);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });

    const reveal = Array.from(document.querySelectorAll<HTMLElement>(".rv"));
    let io: IntersectionObserver | null = null;
    if ("IntersectionObserver" in window) {
      io = new IntersectionObserver(
        (entries) =>
          entries.forEach((e) => {
            if (e.isIntersecting) {
              e.target.classList.add("in");
              io?.unobserve(e.target);
            }
          }),
        { rootMargin: "0px 0px -8% 0px" },
      );
      reveal.forEach((el) => io!.observe(el));
    } else {
      reveal.forEach((el) => el.classList.add("in"));
    }

    const caps = Array.from(document.querySelectorAll<HTMLElement>(".bigcap[data-key]"));
    const set = (e: KeyboardEvent, down: boolean) =>
      caps.forEach((c) => {
        if (c.dataset.key === e.key) c.classList.toggle("down", down);
      });
    const onDown = (e: KeyboardEvent) => set(e, true);
    const onUp = (e: KeyboardEvent) => set(e, false);
    const onBlur = () => caps.forEach((c) => c.classList.remove("down"));
    window.addEventListener("keydown", onDown);
    window.addEventListener("keyup", onUp);
    window.addEventListener("blur", onBlur);

    return () => {
      window.removeEventListener("scroll", onScroll);
      io?.disconnect();
      window.removeEventListener("keydown", onDown);
      window.removeEventListener("keyup", onUp);
      window.removeEventListener("blur", onBlur);
    };
  }, []);

  return null;
}
