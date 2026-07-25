/* ************************************************************************************** */
/*                                Прокрутка для слайдов                                   */
/*                                                                                        */

export function initSlidesWheel() {
  document
    .querySelectorAll(".__is_images_slides_container")
    .forEach((slider) => {
      slider.addEventListener("wheel", (event) => {
        if (Math.abs(event.deltaY) > Math.abs(event.deltaX)) {
          event.preventDefault();
          const sign = Math.sign(event.deltaY);
          slider.scrollLeft += sign * slider.offsetWidth;
        }
      });
    });
}

/*                                                                                        */
/* ************************************************************************************** */

/* ************************************************************************************** */
/*                           Переключение классов в навигации                             */
/*                                                                                        */

export function initSlidesNavBar() {
  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          const slideId = entry.target.getAttribute("id");
          const link = document.querySelector(
            `.__is_images_gallery_navbar a[href="#${slideId}"]`,
          );
          if (link) {
            const siblings = link.parentElement.querySelectorAll("a");
            siblings.forEach((a) => a.classList.remove("active"));
            link.classList.add("active");
          }
          if (window.location.hash !== `#${slideId}`) {
            history.replaceState(null, null, `#${slideId}`);
          }
        }
      });
    },
    { threshold: 0.5 },
  );
  document.querySelectorAll(".__is_images_slide_figure").forEach((slide) => {
    observer.observe(slide);
  });
}

/*                                                                                        */
/* ************************************************************************************** */
