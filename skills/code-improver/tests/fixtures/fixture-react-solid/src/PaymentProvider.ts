import { StripeClient } from "stripe-client"; // concrete dependency

export class PaymentProvider {
  private stripe = new StripeClient(); // hard-coded instantiation
  async charge(amount: number): Promise<void> {
    await this.stripe.charge(amount);
  }
}
