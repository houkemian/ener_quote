import logging

def _setup_logging() -> logging.Logger:
    logger = logging.getLogger("app")
    logger.setLevel(logging.INFO)
    if not logger.handlers:
        handler = logging.StreamHandler()
        handler.setFormatter(
            logging.Formatter(
                "%(asctime)s | %(levelname)s | %(name)s | %(message)s"
            )
        )
        logger.addHandler(handler)
        logger.propagate = False
    return logger


logger = _setup_logging()


def main():
    logger.info("Hello from pv-ess-quote-backend!")


if __name__ == "__main__":
    main()
