public class StripeCheckoutSession {
    public Data data { get; set; }

    public class Data {
        public CheckoutSessionObject checkoutSessionObject { get; set; }
    }

    public class CheckoutSessionObject {
        public Metadata metadata { get; set; }
    }

    public class Metadata {
        public String work_order_id { get; set; }
    }
}