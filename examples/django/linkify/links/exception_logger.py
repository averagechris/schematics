class ConsoleExceptionMiddleware:
    def process_exception(self, request, exception):
        import sys
        import traceback

        exc_info = sys.exc_info()
        print("######################## Exception #############################")
        print("\n".join(traceback.format_exception(*(exc_info or sys.exc_info()))))
        print("################################################################")
