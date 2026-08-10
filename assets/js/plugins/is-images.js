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
        }
      });
    },
    { threshold: 0.5 },
  );
  document.querySelectorAll(".__is_images_slide_figure").forEach((slide) => {
    observer.observe(slide);
  });
  document
    .querySelectorAll(".__is_images_gallery_navbar a")
    .forEach((button) => {
      console.log({button:button});
      button.addEventListener("click", (e) => {
        const href = button.getAttribute('href');
        const target = document.querySelector(href);
        if (target) {
          e.preventDefault();
          target.scrollIntoView({ behavior: 'smooth' });
        }
      });
    });
}

/*                                                                                        */
/* ************************************************************************************** */

/* ************************************************************************************** */
/*                                     Просмотр картинок                                  */
/*                                                                                        */

export function initViewBox() {
  let viewbox = document.querySelector(".__is_images_viewbox");
  let image = !!viewbox
    ? viewbox.querySelector(".__is_images_viewbox_image")
    : null;
  let caption = !!viewbox
    ? viewbox.querySelector(".__is_images_viewbox_caption")
    : null;
  let spinner = !!viewbox
    ? viewbox.querySelector(".__is_images_viewbox_spinner")
    : null;

  function createViewBox() {
    viewbox = document.createElement("figure");
    viewbox.className = "__is_images_viewbox";
    image = document.createElement("img");
    image.className = "__is_images_viewbox_image";
    image.alt = "";
    caption = document.createElement("figcaption");
    caption.className = "__is_images_viewbox_caption";
    spinner = document.createElement("div");
    spinner.className = "__is_images_viewbox_spinner";

    image.addEventListener("load", () => {
      console.log({ load: image });
      spinner.style.display = "none";
      image.classList.add("loaded");
      if (caption.textContent.trim() != "") {
        caption.classList.add("visible");
      }
    });

    viewbox.appendChild(spinner);
    viewbox.appendChild(image);
    viewbox.appendChild(caption);
    document.body.appendChild(viewbox);

    viewbox.addEventListener("click", (event) => {
      if (event.target === viewbox) {
        closeViewBox();
      }
    });
  }

  function closeViewBox() {
    if (!viewbox || !viewbox.classList.contains("active")) return;
    viewbox.classList.remove("active");
    image.classList.remove("loaded");
    caption.classList.remove("visible");
  }

  document.addEventListener("click", (event) => {
    const link = event.target.closest("a");
    if (!link) return;
    const url = link.href;
    const isImage = /\.(jpeg|jpg|png|gif|webp|avif|svg)$/i.test(url);
    if (isImage) {
      event.preventDefault();
      if (!viewbox) {
        createViewBox();
      }
      image.classList.remove("loaded");
      caption.classList.remove("visible");
      spinner.style.display = "block";

      const img = link.querySelector("img");
      const captionHTML = !!img ? img.dataset.caption || "" : "";
      caption.innerHTML = captionHTML;
      image.src = url;
      image.alt = img.alt;
      viewbox.classList.add("active");
      console.log({ viewbox: viewbox });
    }
  });

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") {
      closeViewBox();
    }
  });
}

/*                                                                                        */
/* ************************************************************************************** */
