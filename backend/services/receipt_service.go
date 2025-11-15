package services

import (
	"bstock/models"
	"bytes"
	"fmt"
)

type ReceiptService struct{}

func NewReceiptService() *ReceiptService {
	return &ReceiptService{}
}

// GenerateReceipt generates a simple text receipt (PDF in production)
func (s *ReceiptService) GenerateReceipt(sale *models.Sale, org *models.Organization) ([]byte, error) {
	var buf bytes.Buffer

	buf.WriteString("===============================\n")
	buf.WriteString(fmt.Sprintf("     %s\n", org.Name))
	buf.WriteString("===============================\n\n")
	buf.WriteString(fmt.Sprintf("Receipt #: %s\n", sale.ID.String()[:8]))
	buf.WriteString(fmt.Sprintf("Date: %s\n", sale.CreatedAt.Format("2006-01-02 15:04:05")))
	buf.WriteString(fmt.Sprintf("Cashier: %s\n", sale.User.PhoneNumber))
	buf.WriteString("\n-------------------------------\n")
	buf.WriteString("ITEMS\n")
	buf.WriteString("-------------------------------\n")

	for _, item := range sale.Items {
		productName := "Unknown"
		if item.Variant.Product.Name != "" {
			productName = item.Variant.Product.Name
		}
		buf.WriteString(fmt.Sprintf("%dx %s\n", item.Quantity, productName))
		buf.WriteString(fmt.Sprintf("   @ %.2f = %.2f\n", item.PriceAtSale, float64(item.Quantity)*item.PriceAtSale))
	}

	buf.WriteString("\n-------------------------------\n")
	buf.WriteString(fmt.Sprintf("TOTAL: %.2f ETB\n", sale.TotalAmount))
	buf.WriteString(fmt.Sprintf("Payment: %s\n", sale.PaymentMethod))
	buf.WriteString("-------------------------------\n\n")
	buf.WriteString("Thank you for your business!\n")
	buf.WriteString("===============================\n")

	return buf.Bytes(), nil
}
